//
//  HomeNavigationView.swift
//  BPDeliverer
//
//  Created by yangjian on 2023/12/1.
//

import SwiftUI
import ComposableArchitecture

struct HomeNavigationReducer: Reducer {
    struct State: Equatable {
        var path: StackState<Path.State> = .init()
        var root: HomeReducer.State = .init()
    }
    enum Action: Equatable {
        case path(StackAction<Path.State, Path.Action>)
        case root(HomeReducer.Action)
    }
    var body: some Reducer<State, Action> {
        Reduce{ state, action in
            switch action{
            case let .root(.tracker(.itemSelected(measure))):
                state.pushDetailView(measure)
            case .root(.profile(.reminderButtonTapped)):
                state.pushreminderView()
            case .root(.profile(.privacyButtonTapped)):
                state.pushPrivacyView()
            case .root(.profile(.languageButtonTapped)):
                state.pushLanguageView()
            case .path(.element(id: _, action: .detail(.pop))), .path(.element(id: _, action: .reminder(.pop))), .path(.element(id: _, action: .privacy(.pop))), .path(.element(id: _, action: .language(.pop))):
                state.popView()
            case let .path(.element(id: id, action: .detail(.delete))):
                if case let .detail(detailState) = state.path[id: id] {
                    state.deleteMeasure(detailState.measure)
                }
            case let .path(.element(id: id, action: .detail(.editButtonTapped))):
                if case let .detail(detailState) = state.path[id: id] {
                    state.popView()
                    state.root.presentAddView(detailState.measure, status: .edit)
                }
            case let .path(.element(id: _, action: .language(.itemSelected(language)))):
                let reminders = UserDefaults.standard.getObject([String].self, forKey: .reminder)
                reminders?.forEach({
                    NotificationHelper.shared.appendReminder($0, localID: language.code)
                })
            default:
                break
            }
            return .none
        }.forEach(\.path, action: /Action.path) {
            Path()
        }
        Scope(state: \.root, action: /Action.root) {
            HomeReducer()
        }
    }
    
    struct Path: Reducer {
        enum State: Equatable {
            case detail(DetailReducer.State)
            case reminder(ReminderReducer.State)
            case privacy(PrivacyReducer.State)
            case language(LanguageReducer.State)
        }
        enum Action: Equatable {
            case detail(DetailReducer.Action)
            case reminder(ReminderReducer.Action)
            case privacy(PrivacyReducer.Action)
            case language(LanguageReducer.Action)
        }
        var body: some Reducer<State, Action> {
            Reduce{ state, action in
                return .none
            }
            Scope(state: /State.detail, action: /Action.detail) {
                DetailReducer()
            }
            Scope(state: /State.reminder, action: /Action.reminder) {
                ReminderReducer()
            }
            Scope(state: /State.privacy, action: /Action.privacy) {
                PrivacyReducer()
            }
            Scope(state: /State.language, action: /Action.language) {
                LanguageReducer()
            }
        }
    }

}

extension HomeNavigationReducer.State {
    mutating func pushDetailView(_ measure: Measurement) {
        path.append(.detail(.init(measure: measure)))
    }
    
    mutating func pushreminderView() {
        path.append(.reminder(.init()))
    }
    
    mutating func pushPrivacyView() {
        path.append(.privacy(.init()))
    }
    
    mutating func pushLanguageView() {
        path.append(.language(.init()))
    }
    
    mutating func popView() {
        _ = path.popLast()
    }
    
    mutating func deleteMeasure(_ measure: Measurement) {
        root.measures = root.measures.filter {
            $0.id != measure.id
        }
        root.updateMeasure()
        popView()
    }
    
}

struct HomeNavigationView: View {
    let store: StoreOf<HomeNavigationReducer>
    var body: some View {
        NavigationStackStore(store.scope(state: \.path, action: {.path($0)})) {
            HomeView(store: store.scope(state: \.root, action: HomeNavigationReducer.Action.root))
        } destination: {
            switch $0 {
            case .detail:
                CaseLet(/HomeNavigationReducer.Path.State.detail, action: HomeNavigationReducer.Path.Action.detail, then: DetailView.init(store:))
            case .reminder:
                CaseLet(/HomeNavigationReducer.Path.State.reminder, action: HomeNavigationReducer.Path.Action.reminder, then: ReminderView.init(store:))
            case .privacy:
                CaseLet(/HomeNavigationReducer.Path.State.privacy, action: HomeNavigationReducer.Path.Action.privacy, then: PrivacyView.init(store:))
            case .language:
                CaseLet(/HomeNavigationReducer.Path.State.language, action: HomeNavigationReducer.Path.Action.language, then: LanguageView.init(store:))
            }
        }

    }
}
