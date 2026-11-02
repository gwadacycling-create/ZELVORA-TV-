import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'parental_state.dart';
import 'sources_state.dart';

const kProfilesKey = 'zelvora.profiles.v1';
const kMainProfileId = 'main';

/// Un profil : ses favoris, son historique et sa progression sont séparés.
/// Un profil Enfant cache toujours les contenus adultes.
class Profile {
  const Profile({required this.id, required this.name, this.kids = false});
  final String id;
  final String name;
  final bool kids;

  Map<String, dynamic> toJson() => {'i': id, 'n': name, 'k': kids};
  static Profile fromJson(Map j) => Profile(id: '${j['i']}', name: '${j['n']}', kids: j['k'] == true);

  @override
  bool operator ==(Object other) => other is Profile && other.id == id && other.name == name && other.kids == kids;
  @override
  int get hashCode => Object.hash(id, name, kids);
}

class ProfilesState {
  const ProfilesState(this.list, this.currentId);
  static const initial = ProfilesState([Profile(id: kMainProfileId, name: 'Principal')], kMainProfileId);

  final List<Profile> list;
  final String currentId;
  Profile get current => list.firstWhere((p) => p.id == currentId, orElse: () => list.first);

  String encode() => jsonEncode({'l': [for (final p in list) p.toJson()], 'c': currentId});
  static ProfilesState decode(String? raw) {
    if (raw == null) return initial;
    try {
      final j = jsonDecode(raw) as Map;
      final list = [for (final e in j['l'] as List) Profile.fromJson(e as Map)];
      if (list.isEmpty || list.first.id != kMainProfileId) return initial;
      return ProfilesState(list, '${j['c']}');
    } catch (_) {
      return initial;
    }
  }
}

/// Profils lus au démarrage (avant l'affichage).
final initialProfilesProvider = Provider<ProfilesState>((ref) => ProfilesState.initial);

final profilesProvider = NotifierProvider<ProfilesNotifier, ProfilesState>(ProfilesNotifier.new);

class ProfilesNotifier extends Notifier<ProfilesState> {
  @override
  ProfilesState build() => ref.read(initialProfilesProvider);

  Future<Profile> add(String name, {bool kids = false}) async {
    final p = Profile(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      name: name.trim().isEmpty ? (kids ? 'Enfant' : 'Profil ${state.list.length + 1}') : name.trim(),
      kids: kids,
    );
    await _set(ProfilesState([...state.list, p], state.currentId));
    return p;
  }

  /// Le profil Principal ne peut pas être supprimé.
  Future<void> remove(String id) async {
    if (id == kMainProfileId) return;
    final list = state.list.where((p) => p.id != id).toList();
    await _set(ProfilesState(list, state.currentId == id ? kMainProfileId : state.currentId));
  }

  Future<void> select(String id) => _set(ProfilesState(state.list, id));

  Future<void> _set(ProfilesState s) async {
    state = s;
    await ref.read(secureStoreProvider).write(kProfilesKey, s.encode());
  }
}

final currentProfileProvider = Provider<Profile>((ref) => ref.watch(profilesProvider.select((s) => s.current)));

/// Clé d'enregistrement propre au profil (le profil Principal garde les anciennes données).
String profileKey(String base, Profile p) => p.id == kMainProfileId ? base : '$base.${p.id}';

/// Contenus adultes masqués : contrôle parental actif ou profil Enfant.
final hideAdultProvider = Provider<bool>(
  (ref) => ref.watch(parentalProvider.select((p) => p.enabled)) || ref.watch(currentProfileProvider).kids,
);
