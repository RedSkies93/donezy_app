class FirestorePaths {
  static String familyDoc(String familyId) => 'families/$familyId';

  static String tasksCol(String familyId) => '${familyDoc(familyId)}/tasks';
  static String childrenCol(String familyId) => '${familyDoc(familyId)}/children';
  static String rewardsCol(String familyId) => '${familyDoc(familyId)}/rewards';
  static String chatsCol(String familyId) => '${familyDoc(familyId)}/chats';
}
