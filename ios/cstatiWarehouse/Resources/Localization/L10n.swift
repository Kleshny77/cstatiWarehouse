//
//  L10n.swift
//  cstatiWarehouse
//
//  Created by Артём on 29.04.2026.
//

import Foundation

enum L10n {
    
    // MARK: - Common
    
    static let cancel = NSLocalizedString("common.cancel", comment: "")
    static let done = NSLocalizedString("common.done", comment: "")
    static let save = NSLocalizedString("common.save", comment: "")
    static let delete = NSLocalizedString("common.delete", comment: "")
    static let edit = NSLocalizedString("common.edit", comment: "")
    static let add = NSLocalizedString("common.add", comment: "")
    static let close = NSLocalizedString("common.close", comment: "")
    static let ok = NSLocalizedString("common.ok", comment: "")
    static let yes = NSLocalizedString("common.yes", comment: "")
    static let no = NSLocalizedString("common.no", comment: "")
    static let search = NSLocalizedString("common.search", comment: "")
    static let filter = NSLocalizedString("common.filter", comment: "")
    static let sort = NSLocalizedString("common.sort", comment: "")
    static let loading = NSLocalizedString("common.loading", comment: "")
    static let error = NSLocalizedString("common.error", comment: "")
    static let retry = NSLocalizedString("common.retry", comment: "")
    static let create = NSLocalizedString("common.create", comment: "")
    static let update = NSLocalizedString("common.update", comment: "")
    static let confirm = NSLocalizedString("common.confirm", comment: "")
    static let back = NSLocalizedString("common.back", comment: "")
    
    // MARK: - Tabs
    
    static let tabWarehouse = NSLocalizedString("tab.warehouse", comment: "")
    static let tabOrganization = NSLocalizedString("tab.organization", comment: "")
    static let tabSettings = NSLocalizedString("tab.settings", comment: "")
    
    // MARK: - Warehouse
    
    static let warehouseTitle = NSLocalizedString("warehouse.title", comment: "")
    static let warehouseEmptyTitle = NSLocalizedString("warehouse.empty.title", comment: "")
    static let warehouseEmptySubtitle = NSLocalizedString("warehouse.empty.subtitle", comment: "")
    static let warehouseAddItem = NSLocalizedString("warehouse.add_item", comment: "")
    static let warehouseSearchPlaceholder = NSLocalizedString("warehouse.search.placeholder", comment: "")
    static let warehouseFilterButton = NSLocalizedString("warehouse.filter_button", comment: "")
    static let warehouseSortButton = NSLocalizedString("warehouse.sort_button", comment: "")
    static let warehouseArchiveHistory = NSLocalizedString("warehouse.archive_history", comment: "")
    static let warehouseScopeAll = NSLocalizedString("warehouse.scope.all", comment: "")
    static let warehouseScopeMy = NSLocalizedString("warehouse.scope.my", comment: "")
    
    static func warehouseItemsCount(_ count: Int) -> String {
        String(format: NSLocalizedString("warehouse.items_count", comment: ""), count)
    }
    
    // MARK: - Item
    
    static let itemName = NSLocalizedString("item.name", comment: "")
    static let itemDescription = NSLocalizedString("item.description", comment: "")
    static let itemCategory = NSLocalizedString("item.category", comment: "")
    static let itemQuantity = NSLocalizedString("item.quantity", comment: "")
    static let itemLocation = NSLocalizedString("item.location", comment: "")
    static let itemExpirationDate = NSLocalizedString("item.expiration_date", comment: "")
    static let itemPhoto = NSLocalizedString("item.photo", comment: "")
    static let itemHolder = NSLocalizedString("item.holder", comment: "")
    static let itemMeasureUnit = NSLocalizedString("item.measure_unit", comment: "")
    static let itemVolumePerUnit = NSLocalizedString("item.volume_per_unit", comment: "")
    static let itemPackaging = NSLocalizedString("item.packaging", comment: "")
    static let itemVariant = NSLocalizedString("item.variant", comment: "")
    static let itemAddVariant = NSLocalizedString("item.add_variant", comment: "")
    
    // MARK: - Item Edit
    
    static let itemEditTitle = NSLocalizedString("item_edit.title", comment: "")
    static let itemEditCreate = NSLocalizedString("item_edit.create", comment: "")
    static let itemEditUpdate = NSLocalizedString("item_edit.update", comment: "")
    static let itemEditNamePlaceholder = NSLocalizedString("item_edit.name_placeholder", comment: "")
    static let itemEditDescriptionPlaceholder = NSLocalizedString("item_edit.description_placeholder", comment: "")
    static let itemEditCategoryPlaceholder = NSLocalizedString("item_edit.category_placeholder", comment: "")
    static let itemEditLocationPlaceholder = NSLocalizedString("item_edit.location_placeholder", comment: "")
    static let itemEditSelectPhoto = NSLocalizedString("item_edit.select_photo", comment: "")
    static let itemEditChangePhoto = NSLocalizedString("item_edit.change_photo", comment: "")
    static let itemEditRemovePhoto = NSLocalizedString("item_edit.remove_photo", comment: "")
    
    // MARK: - Archive
    
    static let archiveTitle = NSLocalizedString("archive.title", comment: "")
    static let archiveReason = NSLocalizedString("archive.reason", comment: "")
    static let archiveQuantity = NSLocalizedString("archive.quantity", comment: "")
    static let archiveConfirm = NSLocalizedString("archive.confirm", comment: "")
    static let archiveDetail = NSLocalizedString("archive.detail", comment: "")
    static let archiveHistory = NSLocalizedString("archive.history", comment: "")
    static let archiveEvent = NSLocalizedString("archive.event", comment: "")
    static let archiveSelectEvent = NSLocalizedString("archive.select_event", comment: "")
    
    static let archiveReasonExpired = NSLocalizedString("archive.reason.expired", comment: "")
    static let archiveReasonDamaged = NSLocalizedString("archive.reason.damaged", comment: "")
    static let archiveReasonLost = NSLocalizedString("archive.reason.lost", comment: "")
    static let archiveReasonUsed = NSLocalizedString("archive.reason.used", comment: "")
    static let archiveReasonSold = NSLocalizedString("archive.reason.sold", comment: "")
    static let archiveReasonDonated = NSLocalizedString("archive.reason.donated", comment: "")
    static let archiveReasonUsedAtEvent = NSLocalizedString("archive.reason.used_at_event", comment: "")
    static let archiveReasonOther = NSLocalizedString("archive.reason.other", comment: "")
    
    // MARK: - Organization
    
    static let organizationTitle = NSLocalizedString("organization.title", comment: "")
    static let organizationMembers = NSLocalizedString("organization.members", comment: "")
    static let organizationInvite = NSLocalizedString("organization.invite", comment: "")
    static let organizationEvents = NSLocalizedString("organization.events", comment: "")
    static let organizationActivity = NSLocalizedString("organization.activity", comment: "")
    static let organizationCategories = NSLocalizedString("organization.categories", comment: "")
    static let organizationSettings = NSLocalizedString("organization.settings", comment: "")
    static let organizationLeave = NSLocalizedString("organization.leave", comment: "")
    static let organizationCreate = NSLocalizedString("organization.create", comment: "")
    static let organizationJoin = NSLocalizedString("organization.join", comment: "")
    static let organizationSwitch = NSLocalizedString("organization.switch", comment: "")
    static let organizationName = NSLocalizedString("organization.name", comment: "")
    static let organizationCode = NSLocalizedString("organization.code", comment: "")
    
    static let organizationRoleOwner = NSLocalizedString("organization.role.owner", comment: "")
    static let organizationRoleAdmin = NSLocalizedString("organization.role.admin", comment: "")
    static let organizationRoleMember = NSLocalizedString("organization.role.member", comment: "")
    
    // MARK: - Settings
    
    static let settingsTitle = NSLocalizedString("settings.title", comment: "")
    static let settingsProfile = NSLocalizedString("settings.profile", comment: "")
    static let settingsNotifications = NSLocalizedString("settings.notifications", comment: "")
    static let settingsLanguage = NSLocalizedString("settings.language", comment: "")
    static let settingsLogout = NSLocalizedString("settings.logout", comment: "")
    static let settingsVersion = NSLocalizedString("settings.version", comment: "")
    static let settingsAbout = NSLocalizedString("settings.about", comment: "")
    
    // MARK: - Auth
    
    static let authLogin = NSLocalizedString("auth.login", comment: "")
    static let authRegister = NSLocalizedString("auth.register", comment: "")
    static let authEmail = NSLocalizedString("auth.email", comment: "")
    static let authPassword = NSLocalizedString("auth.password", comment: "")
    static let authName = NSLocalizedString("auth.name", comment: "")
    static let authLoginWithTelegram = NSLocalizedString("auth.login_telegram", comment: "")
    static let authLoginWithGoogle = NSLocalizedString("auth.login_google", comment: "")
    static let authWelcome = NSLocalizedString("auth.welcome", comment: "")
    static let authCreateAccount = NSLocalizedString("auth.create_account", comment: "")
    static let authHaveAccount = NSLocalizedString("auth.have_account", comment: "")
    static let authNoAccount = NSLocalizedString("auth.no_account", comment: "")
    
    // MARK: - Errors
    
    static let errorGeneric = NSLocalizedString("error.generic", comment: "")
    static let errorNetwork = NSLocalizedString("error.network", comment: "")
    static let errorUnauthorized = NSLocalizedString("error.unauthorized", comment: "")
    static let errorNotFound = NSLocalizedString("error.not_found", comment: "")
    static let errorForbidden = NSLocalizedString("error.forbidden", comment: "")
    static let errorValidation = NSLocalizedString("error.validation", comment: "")
    static let errorConflict = NSLocalizedString("error.conflict", comment: "")
    static let errorServerError = NSLocalizedString("error.server_error", comment: "")
    
    // MARK: - Measure Units
    
    static let measureUnitPiece = NSLocalizedString("measure.piece", comment: "")
    static let measureUnitKilogram = NSLocalizedString("measure.kilogram", comment: "")
    static let measureUnitGram = NSLocalizedString("measure.gram", comment: "")
    static let measureUnitLiter = NSLocalizedString("measure.liter", comment: "")
    static let measureUnitMilliliter = NSLocalizedString("measure.milliliter", comment: "")
    static let measureUnitMeter = NSLocalizedString("measure.meter", comment: "")
    static let measureUnitCentimeter = NSLocalizedString("measure.centimeter", comment: "")
    static let measureUnitPackage = NSLocalizedString("measure.package", comment: "")
    static let measureUnitBox = NSLocalizedString("measure.box", comment: "")
    static let measureUnitBottle = NSLocalizedString("measure.bottle", comment: "")
    static let measureUnitCan = NSLocalizedString("measure.can", comment: "")
    
    // MARK: - Expiration Status
    
    static let expirationExpired = NSLocalizedString("expiration.expired", comment: "")
    static let expirationExpiringSoon = NSLocalizedString("expiration.expiring_soon", comment: "")
    static let expirationOk = NSLocalizedString("expiration.ok", comment: "")
    static let expirationNoDate = NSLocalizedString("expiration.no_date", comment: "")
    
    static func expirationExpiredOn(_ date: String) -> String {
        String(format: NSLocalizedString("expiration.expired_on", comment: ""), date)
    }
    
    static func expirationExpiresOn(_ date: String) -> String {
        String(format: NSLocalizedString("expiration.expires_on", comment: ""), date)
    }
    
    static func expirationValidUntil(_ date: String) -> String {
        String(format: NSLocalizedString("expiration.valid_until", comment: ""), date)
    }
    
    // MARK: - Filters
    
    static let filterTitle = NSLocalizedString("filter.title", comment: "")
    static let filterCategory = NSLocalizedString("filter.category", comment: "")
    static let filterHolder = NSLocalizedString("filter.holder", comment: "")
    static let filterExpiration = NSLocalizedString("filter.expiration", comment: "")
    static let filterClear = NSLocalizedString("filter.clear", comment: "")
    static let filterApply = NSLocalizedString("filter.apply", comment: "")
    static let filterAllCategories = NSLocalizedString("filter.all_categories", comment: "")
    static let filterAllHolders = NSLocalizedString("filter.all_holders", comment: "")
    
    // MARK: - Sort
    
    static let sortTitle = NSLocalizedString("sort.title", comment: "")
    static let sortByName = NSLocalizedString("sort.by_name", comment: "")
    static let sortByDate = NSLocalizedString("sort.by_date", comment: "")
    static let sortByQuantity = NSLocalizedString("sort.by_quantity", comment: "")
    static let sortByExpiration = NSLocalizedString("sort.by_expiration", comment: "")
    static let sortByCategory = NSLocalizedString("sort.by_category", comment: "")
    
    // MARK: - Delete Confirmation
    
    static let deleteConfirmTitle = NSLocalizedString("delete.confirm.title", comment: "")
    static let deleteConfirmMessage = NSLocalizedString("delete.confirm.message", comment: "")
    static let deleteConfirmButton = NSLocalizedString("delete.confirm.button", comment: "")
}
