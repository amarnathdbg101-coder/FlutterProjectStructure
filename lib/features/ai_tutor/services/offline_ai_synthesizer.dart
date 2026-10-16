import '../models/chat_message_model.dart';

class OfflineAiSynthesizer {
  static ChatMessageModel generateFallbackResponse(String question, String? sessionId) {
    final clean = question.trim();
    final lower = clean.toLowerCase();

    String solution;
    List<String> chips;

    if (lower.contains('pdf')) {
      solution = r'''### 📄 PDF Generation in StudySilo
Haan, **StudySilo** me aap apne notes, flashcards aur AI study materials ko PDF format me export kar sakte hain!

### Steps to Download PDF:
1. **Notes Screen**: Kisi bhi note ko open karke top-right bar me **"Export PDF"** tap karein.
2. **AI Study Material**: Any AI explanation can be copied or saved into a note for instant PDF export.
3. **Formula Studio**: Formula sheets and cheatsheets can be exported as A4 printable PDF documents.
''';
      chips = ['Show formula studio PDF', 'How to scan multi-page notes?', 'Create PDF study guide'];
    } else if (lower == 'hi' || lower == 'hello' || lower == 'hey' || lower.contains('who are you') || lower.contains('kaun ho')) {
      solution = r'''Hello! 👋 Main aapka **StudySilo AI Study Companion** hoon.

Main aapke academic doubts solve karne, complex concepts ko samjhane, exam tips dene aur formulas explain karne ke liye tayar hoon.

Aap mujhse koi bhi question puch sakte hain — bataiye aaj aap kya padhna chahte hain?''';
      chips = ['Explain Thermodynamics', 'Show Computer Architecture formulas', 'Test my knowledge with a quiz'];
      solution = r'''**Thermodynamics** is the physical science governing energy conversion between heat, mechanical work, and internal energy.

### Core Principles & Formulation
1. **First Law (Conservation of Energy)**:
   Energy cannot be created or destroyed, only transformed:
$$\Delta U = Q - W$$
   - $\Delta U$: Internal energy change of the system.
   - $Q$: Net heat energy added to the system.
   - $W$: Net work done by the system.

2. **Second Law & Carnot Limit**:
   Natural processes proceed in the direction of increasing total entropy. The theoretical maximum thermodynamic efficiency of any heat engine operating between two thermal reservoirs is given by:
$$\eta_{\text{max}} = 1 - \frac{T_C}{T_H}$$
   - $T_H$: Absolute temperature of hot heat source (in Kelvin $K$).
   - $T_C$: Absolute temperature of cold heat sink (in Kelvin $K$).''';
      chips = [];
    } else {
      solution = '''**$clean** is a foundational academic concept with wide practical and theoretical applications.

### Key Logic & Mechanism
1. **Fundamental Principle**:
   Understanding **$clean** helps break down system states and analyze input-output transformations systematically.

2. **Core Formulation**:
${r'$$\text{Output} = f(\text{Inputs}, \text{Constraints})$$'}

3. **Step-by-Step Approach**:
   - Identify the given variables, constraints, and boundary conditions.
   - Apply the governing laws and simplify equations step-by-step.
   - Verify the final analytical or numerical result with correct units.''';
      chips = [];
    }

    return ChatMessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'assistant',
      content: solution,
      followUpQuestions: chips,
      createdAt: DateTime.now(),
      sessionId: sessionId,
    );
  }
}
