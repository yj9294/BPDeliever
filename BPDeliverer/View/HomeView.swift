//
//  HomeView.swift
//  BPDeliverer
//
//  Created by yangjian on 2023/12/1.
//

import SwiftUI
import ComposableArchitecture

struct HomeReducer: Reducer {
    struct State: Equatable {
        
        @UserDefault("allowUser", defaultValue: false)
        var allowUser: Bool

        @UserDefault("measures", defaultValue: [])
        var measures: [Measurement]
        
        @BindingState var item: Item = .tracker
        let items = Item.allCases
        
        var tracker: TrackerReducer.State = .init()
        @PresentationState var add: AddReducer.State? = nil
        @PresentationState var datePicker: DatePickerReducer.State? = nil
        var analytics: ChartsReducer.State = .init()
        var profile: ProfileReducer.State = .init()
    }
    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case tracker(TrackerReducer.Action)
        case analytics(ChartsReducer.Action)
        case profile(ProfileReducer.Action)
        
        case presentAddView
        case add(PresentationAction<AddReducer.Action>)
        case datePicker(PresentationAction<DatePickerReducer.Action>)
        case allowUser
        
        case updateAD(GADNativeViewModel)
    }
    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .presentAddView:
                state.presentAddView()
            case .add(.presented(.root(.dismiss))):
                state.dismissAddView()
                
            case let .add(.presented(.path(.element(id: _, action: .edit(.buttonTapped(measure)))))):
                state.updateMeasures(measure)
                state.dismissAddView()
            case .tracker(.addButtonTapped):
                state.presentAddView()
//            case let .add(.presented(.path(.element(id: id, action: .edit(.dateButtonTapped))))):
//                // 编辑的时候不跳转，新增才跳转
//                if case let .edit(editState) = state.add?.path[id: id] {
//                    if state.measures.contains(where: { $0.id != editState.measure.id }) {
//                        state.presentDatePickerView(position: .newMeasure)
//                    }
//                }
            case .datePicker(.presented(.cancel)):
                state.dismissDatePickerView()
            case let .datePicker(.presented(.ok(date,postion))):
                state.updateDate(date, position: postion)
                state.dismissDatePickerView()
                Request.tbaRequest(event: .trackDateSelected)
            case .tracker(.filterDateMinTapped):
                let min = state.tracker.filterDuration.min
                state.presentDatePickerView(min, position: .filterMin)
                Request.tbaRequest(event: .trackDateChange)
            case .tracker(.filterDateMaxTapped):
                let max = state.tracker.filterDuration.min
                state.presentDatePickerView(max, position: .filterMax)
                Request.tbaRequest(event: .trackDateChange)
            case .tracker(.guide):
                state.presentAddView()
        
                
            case .tracker(.showAD):
                state.showAD(.tracker)
            case .profile(.showAD):
                state.showAD(.profile)
            case .add(.presented(.root(.showAD))):
                state.showAD(.add)
            case let .updateAD(model):
                state.updateAD(model)
                
            case .allowUser:
                state.allowUser = true
            default:
                break
            }
            return .none
        }.ifLet(\.$add, action: /Action.add) {
            AddReducer()
        }.ifLet(\.$datePicker, action: /Action.datePicker) {
            DatePickerReducer()
        }
        Scope(state: \.tracker, action: /Action.tracker) {
            TrackerReducer()
        }
        Scope(state: \.analytics, action: /Action.analytics) {
            ChartsReducer()
        }
        Scope(state: \.profile, action: /Action.profile) {
            ProfileReducer()
        }
    }
}

extension HomeReducer.State {
    enum Item: String, CaseIterable {
        case tracker, analytics, profile
        var icon: String{
            return "home_" + self.rawValue
        }
        var  selectedIcon: String {
            return icon + "_1"
        }
        var title: String {
            return self.rawValue
        }
    }
    
    mutating func presentAddView(_ measure: Measurement = .init(), status: AddReducer.RootReducer.State.Status = .new) {
        GADUtil.share.disappear(.tracker)
        GADUtil.share.load(.submit)
        add = .init(root: .init(measure: measure, status: status))
    }
    
    mutating func dismissAddView() {
        add = nil
        GADUtil.share.disappear(.tracker)
        GADUtil.share.load(.tracker)
        if CacheUtil.shared.isUserGo {
            GADUtil.share.load(.enter)
        }
        
        Request.tbaRequest(event: .track)
        Request.tbaRequest(event: .home)
        Request.tbaRequest(event: .homeShow)
    }
    
    mutating func presentDatePickerView(_ date: Date = Date(), position: DatePickerReducer.State.Position) {
        datePicker = .init(date: date, postion: position, components: [.date, .hourAndMinute])
    }
    
    mutating func dismissDatePickerView() {
        datePicker = nil
    }
    
    
    mutating func updateMeasures(_ measure: Measurement) {
        if measures.contains(where: { m in
            m.id == measure.id
        }) {
            measures = measures.compactMap({ m in
                if m.id == measure.id {
                    return measure
                } else {
                    return m
                }
            })
        } else {
            measures.insert(measure, at: 0)
        }
        updateMeasure()
    }
    
    mutating func updateMeasure() {
        tracker.measures = measures
        analytics.measures = measures
    }
    
    mutating func updateDate(_ date: Date, position: DatePickerReducer.State.Position) {
        if case .filterMin = position {
            tracker.filterDuration.min = date
            if date > tracker.filterDuration.max {
                tracker.filterDuration.max = date.addingTimeInterval(.day)
            }
        }
        if case .filterMax = position {
            tracker.filterDuration.max = date
            if date < tracker.filterDuration.min {
                tracker.filterDuration.min = date.addingTimeInterval(-.day)
            }
        }
    }
    
    mutating func showAD(_ item: GADPosition) {
        GADPosition.allCases.filter({$0 == item}).forEach({
            GADUtil.share.disappear($0)
        })
        GADPosition.allCases.filter({$0 == item}).forEach({
            GADUtil.share.load($0)
        })
        switch item {
        case .tracker:
            Request.tbaRequest(event: .homeShow)
        case .add:
            Request.tbaRequest(event: .addShow)
        case .profile:
            Request.tbaRequest(event: .settingShow)
        default:
            break
        }
    }
    
    mutating func updateAD(_ model: GADNativeViewModel) {
        if add != nil, model != .none {
            if CacheUtil.shared.nativeCacheDate.add.canShow {
                add?.root.adModel = model
                CacheUtil.shared.updateNativeCacheDate(.add)
            } else {
                add?.root.adModel = .none
            }
        } else if item == .tracker, model != .none {
            if CacheUtil.shared.nativeCacheDate.tracker.canShow {
                tracker.adModel = model
                CacheUtil.shared.updateNativeCacheDate(.tracker)
            } else {
                tracker.adModel = .none
            }
        } else if item == .profile, model != .none {
            if CacheUtil.shared.nativeCacheDate.profile.canShow {
                profile.adModel = model
                CacheUtil.shared.updateNativeCacheDate(.profile)
            } else {
                profile.adModel = .none
            }
        } else {
            add?.root.adModel = .none
            tracker.adModel = .none
            profile.adModel = .none
        }
    }
}


struct HomeView: View {
    let store: StoreOf<HomeReducer>
    var body: some View {
        WithViewStore(store, observe: {$0}) { viewStore in
            ZStack{
                TabView(selection: viewStore.$item) {
                    ForEach(viewStore.items, id: \.self) { item in
                        ContentView(store: store, item: item)
                    }
                }.fullScreenCover(store: store.scope(state: \.$add, action: {.add($0)})) { store in
                    AddView(store: store)
                }.fullScreenCover(store: store.scope(state: \.$datePicker, action: {.datePicker($0)})) { store in
                    DatePickerView(store: store).background(BackgroundClearView())
                }.onReceive(nativeADPubliser) { noti in
                    if let object = noti.object as? GADNativeModel {
                        viewStore.send(.updateAD(GADNativeViewModel(model: object)))
                    } else {
                        viewStore.send(.updateAD(.none))
                    }
                }
                if !viewStore.allowUser {
                    AllowUserView {
                        Request.tbaRequest(event: .disclaimer)
                        viewStore.send(.allowUser)
                    }
                }
            }
        }
    }
    
    struct ContentView: View {
        let store: StoreOf<HomeReducer>
        let item: HomeReducer.State.Item
        var body: some View {
            WithViewStore(store, observe: {$0}) { viewStore in
                VStack{
                    switch item {
                    case .tracker:
                        TrackerView(store: store.scope(state: \.tracker, action: HomeReducer.Action.tracker))
                    case .analytics:
                        ChartsView(store: store.scope(state: \.analytics, action: HomeReducer.Action.analytics))
                    case .profile:
                        ProfileView(store: store.scope(state: \.profile, action: HomeReducer.Action.profile))
                    }
                }.tabItem {
                    VStack{
                        item != viewStore.item ? Image(item.icon) : Image(item.selectedIcon)
                        Text(LocalizedStringKey(stringLiteral: item.title))
                    }
                }.id(item)
            }
        }
    }
    
    struct AllowUserView: View {
        let action: ()->Void
        var body: some View {
            ZStack{
                Color.black.opacity(0.7)
                VStack{
                    HStack{Spacer()}
                    Spacer()
                    VStack(spacing: 20){
                        Text(LocalizedStringKey("Disclaimer")).font(.system(size: 20, weight: .semibold)).foregroundStyle(Color("#242C44"))
                        Text(LocalizedStringKey("Disclaimer_desc")).font(.system(size: 16)).foregroundStyle(Color("#242C44")).lineLimit(nil).truncationMode(.tail).padding(.horizontal, 30)
                        Button(action: action, label: {
                            Text(LocalizedStringKey("OK")).font(.system(size: 15)).foregroundStyle(.white).padding(.vertical, 15).padding(.horizontal, 100)
                        }).background(Color("#42C3D6")).cornerRadius(26)
                    }.padding(.vertical, 28).background(.white).cornerRadius(10).padding(.horizontal, 35)
                    Spacer()
                }
            }
        }
    }
}
