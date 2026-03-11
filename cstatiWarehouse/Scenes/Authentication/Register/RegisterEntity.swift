//
//  RegisterEntity.swift
//  cstatiWarehouse
//
//  Created by Artem Samsonov on 17.01.2026.
//

import Foundation

struct RegisterEntity {
  let name: String
  let email: String
  let password: String
}

struct PasswordValidation {
  var minLength: Bool
  var hasUppercase: Bool
  var hasLowercase: Bool
  var hasDigit: Bool
  var hasSpecialCharacter: Bool
  
  var isValid: Bool {
    minLength && hasUppercase && hasLowercase && hasDigit && hasSpecialCharacter
  }
  
  static func validate(_ password: String) -> PasswordValidation {
    PasswordValidation(
      minLength: password.count >= 8,
      hasUppercase: password.contains(where: { $0.isLetter && $0.isUppercase }),
      hasLowercase: password.contains(where: { $0.isLetter && $0.isLowercase }),
      hasDigit: password.contains(where: { $0.isNumber }),
      hasSpecialCharacter: password.contains(where: { "!@#$%^&*".contains($0) })
    )
  }
}
