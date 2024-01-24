//
//  ContentView.swift
//  BPDeliverer
//
//  Created by yangjian on 2023/12/1.
//

import SwiftUI
import ComposableArchitecture

struct ContentReducer: Reducer {
    struct State: Equatable {
        var item: Item = .launch
        var launch: LaunchReducer.State = .init()
        var home: HomeNavigationReducer.State = .init()
        
        @UserDefault(.language, defaultValue: getDefaultLanguage())
        var language: String
    }
    enum Action: Equatable {
        case launch(LaunchReducer.Action)
        case home(HomeNavigationReducer.Action)
        
        case item(State.Item)
    }
    var body: some Reducer<State, Action> {
        Reduce{ state, action in
            switch action {
            case .launch(.start):
                state.updateItem(.launch)
            case .launch(.launched):
                if state.launch.isLaunched {
                    state.updateItem(.home)
                }
            case let .home(.path(.element(id: _, action: .language(.update(language))))):
                state.language = language.code
            case let .item(item):
                state.item = item
            default:
                break
            }
            return .none
        }
        Scope(state: \.launch, action: /Action.launch) {
            LaunchReducer()
        }
        Scope(state: \.home, action: /Action.home) {
            HomeNavigationReducer()
        }
    }
}

extension ContentReducer.State {
    mutating func updateItem(_ item: Item) {
        self.item = item
    }
    var isLaunch: Bool {
        item == .launch
    }
    enum Item {
        case launch, home
    }
}

struct ContentView: View {
    @Environment(\.scenePhase) var scenePhase
    let store: StoreOf<ContentReducer>
    var body: some View {
        WithViewStore(store, observe: {$0}) { viewStore in
            VStack{
                if viewStore.state.isLaunch {
                    LaunchView(store: store.scope(state: \.launch, action: ContentReducer.Action.launch))
                } else {
                    HomeNavigationView(store: store.scope(state: \.home, action: ContentReducer.Action.home))
                }
            }.environment(\.locale, .init(identifier: viewStore.language)).onReceive(hotOpenPublisher) { _ in
                viewStore.send(.item(.launch))
                viewStore.send(.launch(.start))
            }
        }
    }
}


func getDefaultLanguage() -> String {
    if let lang = UserDefaults.standard.getObject(String.self, forKey: .language) {
        return lang
    }
    switch Locale.current.identifier {
    case .ar, .en, .de, .fr, .pt, .es:
        return Locale.current.identifier
    default:
        return .en
    }
}
