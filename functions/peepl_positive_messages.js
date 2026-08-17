/**
 * Server-side mirror of peepl_mobile/lib/services/peepl_positive_messages.dart.
 * Keep message text in sync when editing the Dart library.
 */

const POSITIVE_MESSAGES = [
  'You matter.',
  'The world is better with you in it.',
  'You make a difference.',
  'Your presence matters.',
  'You\u2019re important.',
  'You bring something no one else can.',
  'Someone is glad you\u2019re here.',
  'You\u2019re worth knowing.',
  'You have more impact than you realize.',
  'There\u2019s only one you.',
  'You make things better.',
  'Someone is rooting for you.',
  'You have something special.',
  'You\u2019re somebody worth knowing.',
  'You make more difference than you know.',
  'You have something the world needs.',
  'You\u2019re one of a kind.',
  'Someone appreciates you.',
  'You bring something good to the world.',
  'You\u2019re worth appreciating.',
  'Who you are matters.',
  'Your kindness matters.',
  'Your voice matters.',
  'Your ideas matter.',
  'Your perspective matters.',
  'Your story matters.',
  'You make life more interesting.',
  'You bring something uniquely yours.',
  'Someone smiles because of you.',
  'Someone is happy you\u2019re in their life.',
  'Someone thinks about you fondly.',
  'Someone is happy to see your name.',
  'Someone looks forward to seeing you.',
  'Someone enjoys having you around.',
  'Someone is glad they met you.',
  'Someone admires something about you.',
  'Someone appreciates what you bring.',
  'Someone has smiled because of you.',
  'Someone remembers something kind you did.',
  'Someone\u2019s day has been better because of you.',
  'You\u2019re capable of more than you know.',
  'You\u2019re doing better than you think.',
  'Give yourself some credit.',
  'Trust yourself.',
  'You\u2019ve come a long way.',
  'You know more than you realize.',
  'You can figure this out.',
  'You\u2019ve handled hard things before.',
  'You\u2019re stronger than you think.',
  'Don\u2019t underestimate yourself.',
  'You\u2019re worth betting on.',
  'Your potential is still unfolding.',
  'Your best days aren\u2019t all behind you.',
  'There\u2019s more ahead.',
  'Something good could happen today.',
  'The best part might still be ahead.',
  'Today still has possibilities.',
  'Your next chapter is still unwritten.',
  'Life can still surprise you.',
  'Leave room for something wonderful.',
  'Good things are possible.',
  'There are good things ahead.',
  'You have more to discover.',
  'You have memories you haven\u2019t made yet.',
  'You have laughs you haven\u2019t laughed yet.',
  'Your next favorite memory hasn\u2019t happened yet.',
  'You deserve a good day.',
  'You deserve some happiness.',
  'You deserve good people around you.',
  'You deserve moments that make you smile.',
  'You deserve something to look forward to.',
  'Be good to yourself.',
  'Give yourself a little kindness.',
  'Keep being you.',
  'Never forget that you matter.',
  'Tell someone they matter.',
  'Tell someone you\u2019re glad they\u2019re here.',
  'Tell someone you appreciate them.',
  'Tell someone they made you smile.',
  'Tell someone they did a good job.',
  'Tell someone you\u2019re proud of them.',
  'Tell someone you miss them.',
  'Tell someone you\u2019re thinking about them.',
  'Give someone a compliment today.',
  'Let someone know they\u2019re appreciated.',
  'Remind someone how much they mean to you.',
  'Thank someone who deserves to hear it.',
  'Make someone smile today.',
  'Say the nice thing.',
  'Reach out to someone you haven\u2019t talked to lately.',
  'Let someone know you believe in them.',
  'Make someone feel noticed.',
  'Make someone feel welcome.',
  'Make someone feel included.',
  'Give someone a reason to smile.',
  'Send the message you\u2019ve been meaning to send.',
  'Tell someone something you admire about them.',
  'Let someone know you\u2019re happy they\u2019re in your life.',
  'A little kindness can change someone\u2019s whole day.',
  'Make someone\u2019s world a little better today.',
];

const ELIGIBLE_PUSH_TYPES = new Set([
  'walk_in_prompt',
  'crowdsource_request',
  'crowdsource_response',
  'post_liked',
  'new_post_nearby',
  'crowd_change_alert',
  'arrival_fulfilled',
]);

function hashString(value) {
  let hash = 0;
  for (let i = 0; i < value.length; i += 1) {
    hash = ((hash << 5) - hash) + value.charCodeAt(i);
    hash |= 0;
  }
  return Math.abs(hash);
}

function isEligiblePushType(notificationType) {
  return ELIGIBLE_PUSH_TYPES.has(notificationType || '');
}

function shouldIncludePositiveSignOff(recipientUid) {
  if (!recipientUid) return false;
  const day = Math.floor(Date.now() / 86400000);
  return (hashString(`${recipientUid}:${day}:frequency`) % 2) === 0;
}

function pickPositiveMessageIndex(recipientUid, notificationType) {
  const day = Math.floor(Date.now() / 86400000);
  const seed = hashString(`${recipientUid}:${notificationType}:${day}`);
  return seed % POSITIVE_MESSAGES.length;
}

function appendPositiveToBody(body, { recipientUid, notificationType }) {
  const trimmed = (body || '').trim();
  if (!trimmed) return body;
  if (!isEligiblePushType(notificationType)) return body;
  if (!shouldIncludePositiveSignOff(recipientUid)) return body;

  const index = pickPositiveMessageIndex(recipientUid, notificationType);
  return `${trimmed}\n${POSITIVE_MESSAGES[index]}`;
}

module.exports = {
  POSITIVE_MESSAGES,
  ELIGIBLE_PUSH_TYPES,
  isEligiblePushType,
  appendPositiveToBody,
};
