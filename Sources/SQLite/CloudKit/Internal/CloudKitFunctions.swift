#if CloudKit
#if canImport(CloudKit)
  import CloudKit
  import Foundation
  import SQL

  @DatabaseFunction(
    "swiftsqlite_icloud_hasPermission",
    as: ((_SystemFieldsRepresentation<CKShare>?) -> Bool).self,
    isDeterministic: true
  )
  func hasPermission(_ share: CKShare?) -> Bool {
    guard let share else { return true }
    return share.publicPermission == .readWrite
      || share.currentUserParticipant?.permission == .readWrite
  }
#endif

#endif
