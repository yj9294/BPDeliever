//
//  HomeView.swift
//  BPDeliverer
//
//  Created by yangjian on 2023/12/1.
//

import SwiftUI
import Combine
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
        @PresentationState var history: HistoryReducer.State? = nil
        var analytics: ChartsReducer.State = .init()
        var profile: ProfileReducer.State = .init()
        
        @UserDefault("notiAlert", defaultValue: NotiAlertModel())
        var alertModel: NotiAlertModel
        
        var showNotiAlertView: Bool = CacheUtil.shared.getNeedNotiAlert()
        
        var notiAlert: NotificationAlertReducer.State = .init()
        
        var lastItem: Item = .tracker
        
        var isShowMeasureGuide = true
        var isShowReadingGuide = false
    }
    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case tracker(TrackerReducer.Action)
        case analytics(ChartsReducer.Action)
        case profile(ProfileReducer.Action)
        
        case presentAddView
        case add(PresentationAction<AddReducer.Action>)
        case datePicker(PresentationAction<DatePickerReducer.Action>)
        case history(PresentationAction<HistoryReducer.Action>)
        case allowUser
        
        case updateAD(GADNativeViewModel)
        
        case notiAlert(NotificationAlertReducer.Action)
        
        case updateLastItem(State.Item)
        case updateShowReadingGuide(Bool)
        case updateShowMeasureGuide(Bool)
        case okButtonTapped
        case showLogAD
        case showTrackerBarAD
    }
    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .presentAddView:
                state.presentAddView()
            case .add(.presented(.root(.dismiss))):
                state.dismissAddView()
                return .run { send in
                    await send(.tracker(.showTrackerAD))
                }
                
            // 新增 血压 （关闭广告后）
            case let .add(.presented(.path(.element(id: _, action: .edit(.saveButtonTapped(measure)))))):
                state.showNotiAlertView = CacheUtil.shared.getNeedNotiAlert()
                state.updateMeasures(measure)
                state.dismissAddView()
                return .run { send in
                    await send(.updateShowReadingGuide(true))
                }
            case .tracker(.addButtonTapped):
                return .run { send in
                    await send(.showLogAD)
                }
            case .analytics(.historyButtonTapped):
                state.presentHistoryView()
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
                
            case .tracker(.showTrackerAD):
                state.showAD(.tracker)
            case .profile(.showProfileAD):
                state.showAD(.profile)
            case .add(.presented(.root(.showAddAD))):
                state.showAD(.add)
            case let .updateAD(model):
                state.updateAD(model)
                
            case .allowUser:
                state.allowUser = true
                
            case .notiAlert(.dismiss):
                state.showNotiAlertView = false
            case .notiAlert(.gotoSetting):
                state.showNotiAlertView = false
                
            case let .updateLastItem(item):
                state.lastItem = item
            case let .updateShowReadingGuide(showReadingGuide):
                state.isShowReadingGuide = showReadingGuide
            case let .updateShowMeasureGuide(showMeasureGuide):
                state.isShowMeasureGuide = showMeasureGuide
                
            // 进入历史血压列表
            case .history(.presented(.dismiss)):
                state.dismissHistoryView()
            case .history(.presented(.itemSelected)):
                state.dismissHistoryView()
            
            case .showLogAD:
                let publisher = Future<Action, Never> { promiss in
                    GADUtil.share.load(.log)
                    GADUtil.share.show(.log) { _ in
                        promiss(.success(.presentAddView))
                    }
                }
                return .publisher {
                    publisher
                }
            case .showTrackerBarAD:
                let publiser = Future<Action, Never> { promise in
                    GADUtil.share.load(.trackerBar)
                    GADUtil.share.show(.trackerBar) { _ in
                        promise(.success(.tracker(.showTrackerAD)))
                    }
                }
                return .publisher{
                    publiser
                }
            default:
                break
            }
            return .none
        }.ifLet(\.$add, action: /Action.add) {
            AddReducer()
        }.ifLet(\.$datePicker, action: /Action.datePicker) {
            DatePickerReducer()
        }.ifLet(\.$history, action: /Action.history) {
            HistoryReducer()
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
        
        Scope(state: \.notiAlert, action: /Action.notiAlert) {
            NotificationAlertReducer()
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
        add = .init(root: .init(measure: measure, status: status))
    }
    
    mutating func presentHistoryView() {
        history = .init()
    }
    
    mutating func dismissHistoryView() {
        history = nil
    }
    
    mutating func dismissAddView() {
        add = nil
        if item == .tracker {
            Request.tbaRequest(event: .track)
            Request.tbaRequest(event: .trackerAD)
            Request.tbaRequest(event: .trackerADShow)
        }
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
            Request.tbaRequest(event: .trackerADShow)
        case .add:
            Request.tbaRequest(event: .addADShow)
        case .profile:
            Request.tbaRequest(event: .profileADShow)
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
                }.fullScreenCover(store: store.scope(state: \.$history, action: {.history($0)})) { store in
                    HistoryView(store: store)
                }.fullScreenCover(store: store.scope(state: \.$datePicker, action: {.datePicker($0)})) { store in
                    DatePickerView(store: store).background(BackgroundClearView())
                }.onReceive(nativeADPubliser) { noti in
                    if let object = noti.object as? GADNativeModel {
                        viewStore.send(.updateAD(GADNativeViewModel(model: object)))
                    } else {
                        viewStore.send(.updateAD(.none))
                    }
                }.onChange(of: viewStore.item) { newValue in
                    if viewStore.item != viewStore.state.lastItem {
                        if viewStore.item == .tracker {
                            viewStore.send(.showTrackerBarAD)
                            Request.tbaRequest(event: .trackerBarAD)
                        } else {
                            GADUtil.share.load(.trackerBar)
                        }
                    }
                    viewStore.send(.updateLastItem(newValue))
                }
                
                if viewStore.measures.isEmpty, viewStore.isShowMeasureGuide {
                    MeasureGuideView {
                        viewStore.send(.updateShowMeasureGuide(false))
                        viewStore.send(.showLogAD)
                        Request.tbaRequest(event: .trackAdd)
                        Request.tbaRequest(event: .guideAdd)
                        Request.tbaRequest(event: .logAD)
                    } skip: {
                        viewStore.send(.updateShowMeasureGuide(false))
                        // 关闭引导弹窗
                        viewStore.send(.tracker(.showTrackerAD))
                        Request.tbaRequest(event: .guideSkip)
                    }
                }
                
                // reading 引导
                if viewStore.isShowReadingGuide {
                    ReadingGuideView {
                        viewStore.send(.updateShowReadingGuide(false))
                        viewStore.send(.okButtonTapped)
                        Request.tbaRequest(event: .readingGuideAgreen)
                    } skip: {
                        viewStore.send(.updateShowReadingGuide(false))
                        Request.tbaRequest(event: .readingGuideDisagreen)
                        // 关闭引导弹窗
                        if !viewStore.measures.isEmpty || !viewStore.isShowMeasureGuide {
                            viewStore.send(.tracker(.showTrackerAD))
                        }
                    }.onAppear{
                        Request.tbaRequest(event: .readingGuide)
                        if CacheUtil.shared.isUserGo {
                            GADUtil.share.load(.enter)
                        }
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
    
    struct ReadingGuideView: View {
        let ok: ()->Void
        let skip: ()->Void
        @State var time: Int = 5
        let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
        var body: some View {
            ZStack{
                Color.black.opacity(0.7).ignoresSafeArea()
                VStack{
                    HStack{Spacer()}.frame(height: 1)
                    Spacer()
                    VStack(spacing: 18){
                        Image("reading_guide")
                        Text("Try to learn more about blood pressure health!").lineLimit(nil).multilineTextAlignment(.center).foregroundStyle(Color("#53545C")).font(.system(size: 16))
                        VStack(spacing: 12){
                            Button{
                                ok()
                            } label: {
                                HStack{
                                    Spacer()
                                    Text("ok").padding(.vertical,15).foregroundStyle(.white)
                                    Spacer()
                                }
                            }.background(.linearGradient(colors: [Color("#42C3D6"), Color("#5AE9FF")], startPoint: .leading, endPoint: .trailing)).cornerRadius(26).padding(.horizontal, 30)
                            Button {
                                if time == 0 {
                                    skip()
                                }
                            } label: {
                                if time > 0 {
                                    Text("Skip(\(time)s)").foregroundStyle(Color("#B4B3B3"))
                                } else {
                                    Text("Skip").foregroundStyle(Color("#42C3D6"))
                                }
                            }
                        }.font(.system(size: 16))
                    }.padding(.all, 20).background(Color("#F3F8FB")).cornerRadius(16).padding(.horizontal, 20)
                    Spacer()
                }
            }.onReceive(timer) { _ in
                if self.time > 0 {
                    self.time -= 1
                }
            }
        }
    }
    
    struct AllowUserView: View {
        let action: ()->Void
        var body: some View {
            ZStack{
                Color.black.opacity(0.7).ignoresSafeArea()
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
    
    struct MeasureGuideView: View {
        let action: ()->Void
        let skip: ()->Void
        var body: some View {
            ZStack{
                Color.black.opacity(0.9).ignoresSafeArea()
                if CacheUtil.shared.getMeasureGuide() == .b{
                    contentView1(action: action, skip: skip)
                } else {
                    contentView2(action: action, skip: skip)
                }
            }.onAppear {
                Request.tbaRequest(event: .guide)
            }
        }
    }
    
    struct contentView1: View {
        let action: ()->Void
        let skip: ()->Void
        @State var time: Int = 5
        let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
        var color: Color {
            time > 0 ? Color("#BBCDD9") : Color.white
        }
        var title: String {
            time > 0 ? "Skip \(time)s" : "Skip"
        }
        var body: some View {
            VStack(spacing: 30){
                HStack{
                    Spacer()
                    Button(action: {
                        if time == 0 {
                            skip()
                        }
                    }, label: {
                        Text(title).padding(.horizontal, 16).padding(.vertical, 6).background(RoundedRectangle(cornerRadius: 15).stroke(color)).font(.system(size: 13))
                    }).foregroundColor(color).padding(.trailing, 12).padding(.top, 6)
                }
                Spacer()
                VStack(spacing: 0){
                    Image("tracker_guide")
                    Text(LocalizedStringKey("Record blood pressure status")).foregroundStyle(.white).font(.system(size: 17))
                }
                Button {
                    action()
                } label: {
                    HStack(spacing: 7){
                        Spacer()
                        Image("guide_add")
                        Text("Add").foregroundStyle(.white).font(.system(size: 16.0)).padding(.vertical, 15)
                        Spacer()
                    }
                }.background(.linearGradient(colors: [Color("#FFB985"), Color("#F89042")], startPoint: .leading, endPoint: .trailing)).cornerRadius(26).padding(.horizontal, 70)
                Spacer()
            }.onReceive(timer) { _ in
                if self.time > 0 {
                    self.time -= 1
                }
            }
        }
    }

    struct contentView2: View {
        let action: ()->Void
        let skip: ()->Void
        @State var time: Int = 5
        let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
        var color: Color {
            time > 0 ? Color("#BBCDD9") : Color("#194D54")
        }
        var title: String {
            time > 0 ? "Skip \(time)s" : "Skip"
        }
        var body: some View {
            VStack{
                HStack{
                    Spacer()
                    Button(action: {
                        if time == 0 {
                            skip()
                        }
                    }, label: {
                        Text(title).padding(.horizontal, 16).padding(.vertical, 6).background(RoundedRectangle(cornerRadius: 15).stroke(color)).font(.system(size: 13))
                    }).foregroundColor(color).padding(.trailing, 12).padding(.top, 6)
                }
                Spacer()
                VStack(spacing: 33){
                    Image("measure_guide")
                    Text("Please add at least one record to unlock statistics").lineLimit(nil).multilineTextAlignment(.center).padding(.top, 15).font(.system(size: 16)).foregroundColor(.black).padding(.horizontal, 60)
                    Button {
                        action()
                    } label: {
                        HStack{
                            Spacer()
                            Image("guide_add")
                            Text("Add")
                            Spacer()
                        }.foregroundColor(.white)
                    }.background(Image("guide_button_bg"))
                }
                Spacer()
            }.background(.white).onReceive(timer) { _ in
                if self.time > 0 {
                    self.time -= 1
                }
            }
        }
    }
}
