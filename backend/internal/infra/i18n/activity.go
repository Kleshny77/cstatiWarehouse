// Package i18n provides internationalization support for user-facing strings.
// Currently supports Russian language for activity log messages.
package i18n

const (
	ActivityOrgRenamed           = "организация переименована в «%s»"
	ActivityMemberRemoved        = "участник удалён из организации"
	ActivityMemberRoleChanged    = "роль участника изменена на %s"
	ActivityOwnershipTransferred = "владелец организации передал права новому владельцу"
	ActivityMemberJoined         = "новый участник присоединился к организации"

	ActivityCategoryCreated = "добавлена категория «%s»"
	ActivityCategoryDeleted = "удалена категория «%s»"

	ActivityEventCreated = "создано мероприятие «%s»"
	ActivityEventUpdated = "обновлено мероприятие «%s»"
	ActivityEventDeleted = "удалено мероприятие «%s»"

	ActivityItemCreated  = "создана позиция «%s»"
	ActivityItemUpdated  = "обновлена позиция «%s»"
	ActivityItemArchived = "списана позиция «%s» — %s"
	ActivityItemDeleted  = "удалена позиция «%s»"
)

const (
	DefaultWarehouseName          = "Мой склад"
	DefaultWarehouseNameWithOwner = "Склад %s"
	DefaultUserDisplayName        = "Пользователь"
	DefaultPersonalOrgPrefix      = "Склад "
)
