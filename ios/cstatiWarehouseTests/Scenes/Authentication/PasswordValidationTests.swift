//
//  PasswordValidationTests.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import Foundation
import Testing
@testable import cstatiWarehouse

struct PasswordValidationTests {
    @Test
    func validate_allRulesMet_marksValid() {
        let v = PasswordValidation.validate("Abcdef1!")

        #expect(v.minLength)
        #expect(v.hasUppercase)
        #expect(v.hasLowercase)
        #expect(v.hasDigit)
        #expect(v.hasSpecialCharacter)
        #expect(v.isValid)
    }

    @Test
    func validate_tooShort_notValid() {
        let v = PasswordValidation.validate("Ab1!x")
        #expect(v.isValid == false)
        #expect(v.minLength == false)
    }

    @Test
    func validate_missingSpecialCharacter_notValid() {
        let v = PasswordValidation.validate("Abcdef12")
        #expect(v.isValid == false)
        #expect(v.hasSpecialCharacter == false)
    }

    @Test
    func validate_onlyConfiguredSpecialCharsCount() {
        let v = PasswordValidation.validate("Abcdef1#")
        #expect(v.hasSpecialCharacter)
    }
}
