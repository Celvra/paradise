import 'skill.dart';

/// How many skills fit into one listing. The model reads the full text on
/// demand, so the list only needs the entries it can plausibly choose from.
const availableSkillsCap = 20;

/// Descriptions longer than this are clipped in the listing; the full text
/// still ships inside the skill itself.
const availableSkillsDescriptionChars = 200;

/// The listing block appended to the system prompt. Each entry names the id
/// the `read_skill` tool takes, so the model can fetch the instructions for
/// exactly the skill whose description matches the task.
String buildAvailableSkillsFragment(List<Skill> skills) {
  final ordered = List<Skill>.from(skills)
    ..sort((a, b) {
      final byUse = b.useCount.compareTo(a.useCount);
      if (byUse != 0) return byUse;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  if (ordered.length > availableSkillsCap) {
    ordered.removeRange(availableSkillsCap, ordered.length);
  }
  final buf = StringBuffer()
    ..writeln('<available_skills>')
    ..writeln(
      'Use a skill when the task matches its description: call read_skill '
      'with its id first and follow the returned instructions. '
      'Only read the skills you actually need.',
    );
  for (final skill in ordered) {
    final description = clipDescription(skill.description, availableSkillsDescriptionChars);
    buf.writeln('- ${skill.id} — $description');
  }
  buf.write('</available_skills>');
  return buf.toString();
}
