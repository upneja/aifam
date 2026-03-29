import Contacts
import Foundation

struct ContactPerson: Sendable {
    let identifier: String
    let fullName: String
    let birthday: DateComponents?
    let organization: String?
    let relation: String?
    let postalAddresses: [String]
    let phoneNumbers: [String]
    let emailAddresses: [String]
}

struct Household: Sendable {
    let address: String
    let members: [String]
}

@Observable
final class ContactsIngestionService {
    private let store = CNContactStore()

    var contactCount: Int = 0
    var lastSyncDate: Date?

    // MARK: - Fetch All Contacts

    func fetchContacts() -> [ContactPerson] {
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactBirthdayKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactRelationsKey as CNKeyDescriptor,
            CNContactPostalAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactIdentifierKey as CNKeyDescriptor,
        ]

        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        request.sortOrder = .givenName

        var contacts: [ContactPerson] = []

        do {
            try store.enumerateContacts(with: request) { cnContact, _ in
                let fullName = "\(cnContact.givenName) \(cnContact.familyName)".trimmingCharacters(in: .whitespaces)
                guard !fullName.isEmpty else { return }

                let relation = cnContact.contactRelations.first?.label
                    .flatMap { CNLabeledValue<NSString>.localizedString(forLabel: $0) }

                let postalAddresses = cnContact.postalAddresses.map { labeled in
                    CNPostalAddressFormatter.string(from: labeled.value, style: .mailingAddress)
                }

                let person = ContactPerson(
                    identifier: cnContact.identifier,
                    fullName: fullName,
                    birthday: cnContact.birthday,
                    organization: cnContact.organizationName.isEmpty ? nil : cnContact.organizationName,
                    relation: relation,
                    postalAddresses: postalAddresses,
                    phoneNumbers: cnContact.phoneNumbers.map { $0.value.stringValue },
                    emailAddresses: cnContact.emailAddresses.map { $0.value as String }
                )
                contacts.append(person)
            }
        } catch {
            // Permission denied or fetch failed — return empty
        }

        contactCount = contacts.count
        lastSyncDate = Date()
        return contacts
    }

    // MARK: - Extract Birthdays

    func extractBirthdays(from contacts: [ContactPerson]) -> [(name: String, date: DateComponents)] {
        contacts.compactMap { contact in
            guard let birthday = contact.birthday else { return nil }
            return (name: contact.fullName, date: birthday)
        }
    }

    // MARK: - Extract Family Relationships

    func extractRelationships(from contacts: [ContactPerson]) -> [(name: String, relation: String)] {
        contacts.compactMap { contact in
            guard let relation = contact.relation else { return nil }
            return (name: contact.fullName, relation: relation)
        }
    }

    // MARK: - Detect Households (shared addresses)

    func detectHouseholds(from contacts: [ContactPerson]) -> [Household] {
        var addressMap: [String: [String]] = [:]

        for contact in contacts {
            for address in contact.postalAddresses {
                let normalized = normalizeAddress(address)
                guard !normalized.isEmpty else { continue }
                addressMap[normalized, default: []].append(contact.fullName)
            }
        }

        return addressMap
            .filter { $0.value.count >= 2 }
            .map { Household(address: $0.key, members: $0.value) }
            .sorted { $0.members.count > $1.members.count }
    }

    // MARK: - Map to BinderItems

    func mapToBinderItems(contacts: [ContactPerson]) -> [BinderItem] {
        var items: [BinderItem] = []
        let calendar = Calendar.current
        let now = Date()

        let birthdays = extractBirthdays(from: contacts)

        for (name, dateComponents) in birthdays {
            // Calculate next occurrence of birthday
            guard let month = dateComponents.month, let day = dateComponents.day else { continue }

            var nextBirthday = DateComponents()
            nextBirthday.month = month
            nextBirthday.day = day
            nextBirthday.year = calendar.component(.year, from: now)

            guard var birthdayDate = calendar.date(from: nextBirthday) else { continue }

            // If birthday already passed this year, use next year
            if birthdayDate < now {
                nextBirthday.year = calendar.component(.year, from: now) + 1
                guard let nextYear = calendar.date(from: nextBirthday) else { continue }
                birthdayDate = nextYear
            }

            let daysUntil = calendar.dateComponents([.day], from: now, to: birthdayDate).day ?? 0

            // Only include birthdays within 90 days
            guard daysUntil <= 90 else { continue }

            let yearStr: String
            if let year = dateComponents.year {
                let age = calendar.component(.year, from: now) - year
                let nextAge = birthdayDate > now ? age + (nextBirthday.year == calendar.component(.year, from: now) ? 0 : 1) : age
                yearStr = "Turning \(nextAge)"
            } else {
                yearStr = "From contacts"
            }

            let item = BinderItem(
                title: "\(name)'s Birthday",
                detail: "\(formatMonthDay(month: month, day: day)) · \(yearStr)",
                category: .dates,
                dueDate: birthdayDate,
                urgencyDays: daysUntil,
                relatedNotes: daysUntil <= 7 ? ["No gift or plan yet"] : [],
                source: "contacts"
            )
            items.append(item)
        }

        return items
    }

    // MARK: - Helpers

    private func normalizeAddress(_ address: String) -> String {
        address
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    private func formatMonthDay(month: Int, day: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        var components = DateComponents()
        components.month = month
        components.day = day
        components.year = 2026
        guard let date = Calendar.current.date(from: components) else { return "" }
        return formatter.string(from: date)
    }
}
