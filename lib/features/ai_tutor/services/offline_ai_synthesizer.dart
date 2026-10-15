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
    } else if (lower.contains('thermodynamic') || lower.contains('heat') || lower.contains('carnot') || lower.contains('entropy')) {
      solution = r'''### Foundation
- **Core Concept**: **Thermodynamics** is the physical science governing energy conversion between heat, mechanical work, and internal energy.
- **Intuition**: Energy is conserved across all chemical and mechanical transformations (**First Law**), but natural processes proceed spontaneously in the direction of increasing total entropy (**Second Law**).

### Deep Explanation
1. **First Law (Conservation of Energy)**:
$$\Delta U = Q - W$$
Where $\Delta U$ is internal energy change, $Q$ is heat added to system, and $W$ is work done by system.

2. **Second Law & Carnot Maximum Efficiency**:
$$\eta_{\text{max}} = 1 - \frac{T_C}{T_H}$$
Where $T_H$ and $T_C$ are hot and cold reservoir temperatures in Kelvin ($K$).

### 💡 Exam Tips & High-Yield Points
- **Scoring Keywords**: **State Function**, **Isothermal vs Adiabatic**, **Carnot Cycle**, **Entropy $\Delta S$**.
- **Presentation Tip**: Always convert temperatures to **Kelvin ($K = ^\circ\text{C} + 273.15$)** before efficiency calculations!

### ⚠️ Common Misconceptions & Traps
- ❌ **Common Mistake**: Confusing Heat ($Q$) with Temperature ($T$).
- ✅ **Correct Concept**: Temperature is average kinetic energy per particle; Heat is total thermal energy transferred.

### 🔗 Related Concepts
- Carnot Cycle, Ideal Gas Equation ($PV = nRT$), Heat Capacity.

### 📌 Key Takeaways
- Energy is conserved ($\Delta U = Q - W$).
- No heat engine can exceed Carnot efficiency ($1 - T_C/T_H$).''';
      chips = ['Derive Carnot Cycle efficiency', 'Explain Isothermal vs Adiabatic', 'Give 5-mark PYQ numerical'];
    } else {
      solution = '''### Foundation
- **Core Concept**: **$clean** is a fundamental academic topic governing specific system behaviors, equations, and problem-solving rules.
- **Core Intuition**: Understanding **$clean** allows us to predict system states, evaluate quantitative parameters, and solve exam questions systematically.

### Deep Explanation
1. **Mechanism & Mathematical Formulation**:
${r'$$\text{Output} = f(\text{Inputs}, \text{Boundary Constraints})$$'}
2. **Step-by-Step Problem Solving Method**:
   - Identify given physical/algebraic variables and units.
   - Apply governing laws and state formulas clearly.
   - Simplify and box final numerical/analytical results.

### 💡 Exam Tips & High-Yield Points
- **Scoring Keywords**: State key definitions, list assumptions, and show dimensional consistency.
- **Presentation Tip**: Enclose final formulas in a box and specify SI units.

### ⚠️ Common Misconceptions & Traps
- ❌ **Common Mistake**: Forgetting boundary conditions or unit conversions.
- ✅ **Correct Concept**: Always verify units before substituting values into equations.

### 🔗 Related Concepts
- Prerequisite laws, related formulas, and exam numericals.

### 📌 Key Takeaways
- Master standard formulas and state assumptions clearly for full exam credit.''';
      chips = ['Show step-by-step derivation', 'Give a practice numerical question', 'Explain with real-world analogy'];
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
