//
//  ReminderView.swift
//  BPDeliverer
//
//  Created by yangjian on 2023/12/8.
//

import Foundation
import SwiftUI
import Combine
import ComposableArchitecture

struct ReminderReducer: Reducer {
    struct State: Equatable {
        @UserDefault("reminder", defaultValue: ["08:00", "10:00", "12:00", "14:00", "16:00", "18:00", "20:00"])
        var items: [String]
        
        @UserDefault("notification", defaultValue: false)
        var notificationOn: Bool
        
        @UserDefault("sysNotification", defaultValue: false)
        var sysNotificationOn: Bool
        
        @PresentationState var datePicker: DatePickerReducer.State? = nil
    }
    enum Action: Equatable {
        case pop
        case addButtonTapped
        case deleteButtontapped(String)
        case datePicker(PresentationAction<DatePickerReducer.Action>)
        case notifcationToggle
        case gotoSetting
        case onAppear
    }
    var body: some Reducer<State, Action> {
        Reduce{ state, action in
            if case let .deleteButtontapped(item) = action {
                state.deleteItem(item)
                Request.tbaRequest(event: .reminderDelete)
            }
            if case .addButtonTapped = action {
                state.presentDatePickerView()
                Request.tbaRequest(event: .reminderAdd)
            }
            if case .datePicker(.presented(.cancel)) = action {
                state.dismissDatePickerView()
            }
            if case let .datePicker(.presented(.ok(date, _))) = action {
                state.addItem(date.time)
                state.dismissDatePickerView()
            }
            if case .notifcationToggle = action {
                state.notificationOn.toggle()
                CacheUtil.shared.updateMutNotificationOn(isOn: state.notificationOn)
                if !state.notificationOn {
                    NotificationHelper.shared.deleteNotifications(state.items)
                    Request.tbaRequest(event: .notificationMutOff)
                } else {
                    state.items.forEach {
                        NotificationHelper.shared.appendReminder($0)
                    }
                    Request.tbaRequest(event: .notificationMutOn)
                }
            }
            if case .gotoSetting = action {
                state.gotoSetting()
            }
            if case .onAppear = action {
                state.sysNotificationOn = CacheUtil.shared.getSysNotificationOn()
            }
            return .none
        }.ifLet(\.$datePicker, action: /Action.datePicker) {
            DatePickerReducer()
        }
    }
}

extension ReminderReducer.State {
    mutating func deleteItem(_ item: String) {
        items = items.filter({$0 != item})
        NotificationHelper.shared.deleteNotification(item)
    }
    mutating func addItem(_ item: String) {
        items.append(item)
        items.sort { l1, l2 in
            l1 < l2
        }
        NotificationHelper.shared.appendReminder(item)
    }
    mutating func presentDatePickerView() {
        datePicker = .init(date: Date(), postion: .newReminder, components: [.hourAndMinute])
    }
    mutating func dismissDatePickerView() {
        datePicker = nil
    }
    
    func gotoSetting() {
        guard let settingURL = URL(string: UIApplication.openSettingsURLString) else {
            debugPrint("error: settingsURL not found")
            return
        }
        UIApplication.shared.open(settingURL, options: [:]) { ret in
            debugPrint("open settings result:\(ret)")
        }
    }
}

struct ReminderView: View {
    let store: StoreOf<ReminderReducer>
    var body: some View {
        WithViewStore(store, observe: {$0}) { viewStore in
            VStack{
                NotificationHeaderView(store: store)
                ReminderListView(store: store)
            }.onAppear(perform: {
                Request.tbaRequest(event: .backADShow)
                viewStore.items.forEach {
                    NotificationHelper.shared.appendReminder($0)
                }
                Request.tbaRequest(event: .reminder)
            })
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        viewStore.send(.pop)
                    } label: {
                        Image("add_back")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewStore.send(.addButtonTapped)
                    } label: {
                        Image("reminder_add")
                    }
                }
            }
            .navigationTitle(LocalizedStringKey(ProfileReducer.State.Item.reminder.title)).navigationBarTitleDisplayMode(.inline).navigationBarBackButtonHidden()
            .fullScreenCover(store: store.scope(state: \.$datePicker, action: {.datePicker($0)})) { store in
                DatePickerView(store: store).background(BackgroundClearView())
            }.onAppear {
                viewStore.send(.onAppear)
            }
        }.background(Color("#F3F8FB").ignoresSafeArea())
    }
    
    struct NotificationHeaderView: View {
        let store: StoreOf<ReminderReducer>
        var body: some View {
            WithViewStore(store, observe: {$0}) { viewStore in
                HStack{
                    Text(LocalizedStringKey("Message alert permission")).foregroundStyle(.white).font(.system(size: 15))
                    Spacer()
                    Button(action: {
                        viewStore.send(viewStore.sysNotificationOn ? .notifcationToggle : .gotoSetting)
                    }, label: {
                        if viewStore.sysNotificationOn {
                            Image( viewStore.notificationOn ? "notification_on" : "notification_off")
                        } else {
                            HStack(spacing: 0) {
                                Text("not enabled to set").foregroundStyle(Color.white.opacity(0.7)).font(.system(size: 12))
                                Image("arrow_1")
                            }
                        }
                    })
                }.padding(.vertical, 24).padding(.horizontal, 14)
            }.background(Color("#59D5E7").cornerRadius(8)).padding(.all, 20)
        }
    }
    
    struct ReminderListView: View {
        let store: StoreOf<ReminderReducer>
        var body: some View {
            WithViewStore(store, observe: {$0}) { viewStore in
                ScrollView{
                    VStack{
                        LazyVGrid(columns: [GridItem(.flexible())], spacing: 12) {
                            ForEach(viewStore.items, id:\.self) { item in
                                HStack{
                                    HStack{
                                        Text(item).foregroundStyle(.black).font(.system(size: 20))
                                        Spacer()
                                        Button {
                                            viewStore.send(.deleteButtontapped(item))
                                        } label: {
                                            Image("reminder_close")
                                        }
                                    }.padding(.all, 20).shadow(32.0)
                                }.padding(.horizontal, 16)
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
    }
}

#Preview {
    ReminderView(store: Store(initialState: ReminderReducer.State(), reducer: {
        ReminderReducer()
    }))
}
