import Foundation

// MARK: - Care Report Question Model

enum CareReportAnswerType: String, Codable {
    case singleChoice
    case multiChoice
    case optionalText
}

/// Condition for showing a question only when a previous answer matches (e.g. Q5 shown when Q4 == "Yes").
struct CareReportShowWhen: Equatable {
    let questionId: String
    let answerValue: String
}

struct CareReportQuestion: Identifiable {
    let id: String
    let questionText: String
    let answerType: CareReportAnswerType
    let options: [String]
    let isRequired: Bool
    /// When set, this question is only included in the flow when the referenced question's answer equals answerValue.
    let showWhen: CareReportShowWhen?

    init(
        id: String,
        questionText: String,
        answerType: CareReportAnswerType,
        options: [String] = [],
        isRequired: Bool = false,
        showWhen: CareReportShowWhen? = nil
    ) {
        self.id = id
        self.questionText = questionText
        self.answerType = answerType
        self.options = options
        self.isRequired = isRequired
        self.showWhen = showWhen
    }
}

// MARK: - Fixed Caregiver Question Set

enum CareReportQuestionSet {
    /// All caregiver reflection questions in display order. Use for step-by-step flow and report generation.
    static let caregiverQuestions: [CareReportQuestion] = [
        CareReportQuestion(
            id: "q1",
            questionText: "How intense did caregiving feel today?",
            answerType: .singleChoice,
            options: ["Low", "Moderate", "High"],
            isRequired: true
        ),
        CareReportQuestion(
            id: "q2",
            questionText: "What felt most demanding today? (You can select more than one)",
            answerType: .multiChoice,
            options: [
                "Physical tasks (lifting, moving, cleaning)",
                "Emotional support",
                "Managing medications",
                "Communication or coordination",
                "Constant supervision",
                "Nothing specific stood out"
            ],
            isRequired: false
        ),
        CareReportQuestion(
            id: "q3",
            questionText: "Were you able to complete your usual routines today?",
            answerType: .singleChoice,
            options: ["Yes, mostly", "Some routines were missed", "Many routines were missed"],
            isRequired: false
        ),
        CareReportQuestion(
            id: "q4",
            questionText: "Did anything unexpected or concerning happen today?",
            answerType: .singleChoice,
            options: ["No", "Yes"],
            isRequired: false
        ),
        CareReportQuestion(
            id: "q5",
            questionText: "If yes, would you like to briefly describe what happened?",
            answerType: .optionalText,
            options: [],
            isRequired: false,
            showWhen: CareReportShowWhen(questionId: "q4", answerValue: "Yes")
        ),
        CareReportQuestion(
            id: "q6",
            questionText: "What kind of support would help most right now?",
            answerType: .singleChoice,
            options: [
                "Emotional reassurance",
                "Practical advice",
                "Resource suggestions",
                "Just documenting for now",
                "I'm not sure"
            ],
            isRequired: false
        ),
        CareReportQuestion(
            id: "q7",
            questionText: "Is there anything you want a social worker to know?",
            answerType: .optionalText,
            options: [],
            isRequired: false
        )
    ]

    /// Returns questions in order, filtered by visibility given current answers (e.g. Q5 only when Q4 == "Yes").
    static func visibleQuestions(given answers: [String: Any]) -> [CareReportQuestion] {
        caregiverQuestions.filter { question in
            guard let condition = question.showWhen else { return true }
            let previousAnswer = answers[condition.questionId]
            let matches: Bool
            if let single = previousAnswer as? String {
                matches = single == condition.answerValue
            } else if let multi = previousAnswer as? [String] {
                matches = multi.contains(condition.answerValue)
            } else {
                matches = false
            }
            return matches
        }
    }

    /// Steps for the care report flow: q2, q3, q4, (q5 if q4==Yes), q6, q7. Caller supplies intensity separately.
    static func flowSteps(answers: [String: Any]) -> [CareReportQuestion] {
        let q2 = caregiverQuestions[1]
        let q3 = caregiverQuestions[2]
        let q4 = caregiverQuestions[3]
        let q5 = caregiverQuestions[4]
        let q6 = caregiverQuestions[5]
        let q7 = caregiverQuestions[6]
        let showQ5 = (answers["q4"] as? String) == "Yes"
        return [q2, q3, q4] + (showQ5 ? [q5] : []) + [q6, q7]
    }
}

// MARK: - Care Report Draft (UI + state only; no Firestore yet)

struct CareReportDraft {
    var intensity: String
    var answers: [String: Any]

    init(intensity: String, answers: [String: Any] = [:]) {
        self.intensity = intensity
        self.answers = answers
    }

    func answer(for questionId: String) -> Any? { answers[questionId] }
}
