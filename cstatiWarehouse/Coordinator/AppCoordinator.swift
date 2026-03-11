//
//  AppCoordinator.swift
//  cstatiWarehouse
//
//  Created by Artem Samsonov on 17.01.2026.
//

import SwiftUI

enum AppRoute: Hashable {
  case login
  case main
  case register
}

protocol AppCoordinatorProtocol: AnyObject {
  func navigate(to route: AppRoute)
  func pop()
  func popToRoot()
}

@Observable
final class AppCoordinator: AppCoordinatorProtocol {
  var path: NavigationPath = NavigationPath()
  
  func navigate(to route: AppRoute) {
    path.append(route)
  }
  
  func pop() {
    if !path.isEmpty {
      path.removeLast()
    }
  }
  
  func popToRoot() {
    path = NavigationPath()
  }
}
