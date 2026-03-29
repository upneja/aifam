import NaturalLanguage
import Foundation

struct NLEntity: Sendable {
    let text: String
    let type: NLEntityType
    let range: Range<String.Index>
}

enum NLEntityType: String, Sendable {
    case person
    case place
    case organization
    case date
    case unknown
}

final class NLEntityExtractor: Sendable {

    // MARK: - Named Entity Recognition

    func extractEntities(from text: String) -> [NLEntity] {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text

        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
        var entities: [NLEntity] = []

        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .nameType,
            options: options
        ) { tag, tokenRange in
            guard let tag else { return true }

            let entityType: NLEntityType
            switch tag {
            case .personalName:
                entityType = .person
            case .placeName:
                entityType = .place
            case .organizationName:
                entityType = .organization
            default:
                return true
            }

            let entity = NLEntity(
                text: String(text[tokenRange]),
                type: entityType,
                range: tokenRange
            )
            entities.append(entity)

            return true
        }

        return entities
    }

    // MARK: - Person Name Extraction (focused)

    func extractPersonNames(from text: String) -> [String] {
        extractEntities(from: text)
            .filter { $0.type == .person }
            .map { $0.text }
    }

    // MARK: - Place Extraction (focused)

    func extractPlaces(from text: String) -> [String] {
        extractEntities(from: text)
            .filter { $0.type == .place }
            .map { $0.text }
    }

    // MARK: - Organization Extraction (focused)

    func extractOrganizations(from text: String) -> [String] {
        extractEntities(from: text)
            .filter { $0.type == .organization }
            .map { $0.text }
    }

    // MARK: - Sentiment Analysis

    func analyzeSentiment(of text: String) -> Double {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text

        let (sentiment, _) = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
        return Double(sentiment?.rawValue ?? "0") ?? 0
    }

    // MARK: - Language Detection

    func detectLanguage(of text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage?.rawValue
    }

    // MARK: - Tokenization (for preprocessing)

    func tokenize(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text

        var tokens: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { tokenRange, _ in
            tokens.append(String(text[tokenRange]))
            return true
        }

        return tokens
    }

    // MARK: - Cross-reference with Contacts

    func matchEntitiesToContacts(
        entities: [NLEntity],
        contactNames: [String]
    ) -> [(entity: NLEntity, matchedContact: String)] {
        var matches: [(entity: NLEntity, matchedContact: String)] = []

        for entity in entities where entity.type == .person {
            let entityName = entity.text.lowercased()

            // Exact match
            if let match = contactNames.first(where: { $0.lowercased() == entityName }) {
                matches.append((entity: entity, matchedContact: match))
                continue
            }

            // Partial match (first name)
            if let match = contactNames.first(where: {
                $0.lowercased().hasPrefix(entityName) ||
                $0.lowercased().components(separatedBy: " ").first == entityName
            }) {
                matches.append((entity: entity, matchedContact: match))
            }
        }

        return matches
    }
}
