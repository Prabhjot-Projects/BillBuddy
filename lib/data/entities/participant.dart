import 'friend.dart';

/// Reserved id representing the app's own user ("Me") wherever a
/// participant is needed — item assignment, "paid by", split summaries.
///
/// Why a sentinel constant instead of a real row in the friends table:
/// "Me" isn't a friend the user added and shouldn't be editable or
/// deletable through the Friends screen (FriendRepository.delete could
/// otherwise be called on it by accident, silently breaking every past
/// split that referenced it). Keeping FriendRepository's data honest —
/// it only ever returns friends the user explicitly added — is more
/// important than saving a few lines by reusing the same table for both
/// concepts.
///
/// This double-underscore-wrapped string is intentionally not a valid
/// UUID shape, so it can never collide with a real Friend.id generated
/// by Uuid().v4().
const String meParticipantId = '__me__';

/// A lightweight, non-persisted stand-in so "Me" can be displayed and
/// selected using the exact same widgets as a real Friend, without
/// FriendRepository ever needing to know this pseudo-friend exists.
final Friend meParticipant = Friend(id: meParticipantId, name: 'Me');
