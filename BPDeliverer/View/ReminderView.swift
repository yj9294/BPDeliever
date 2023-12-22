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
        @PresentationState var datePicker: DatePickerReducer.State? = nil
    }
    enum Action: Equatable {
        case pop
        case addButtonTapped
        case deleteButtontapped(String)
        case datePicker(PresentationAction<DatePickerReducer.Action>)
        case showAD
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
            if case .showAD = action {
                if CacheUtil.shared.isUserGo {
                    GADUtil.share.load(.back)
                    let publisher = Future<Action, Never> { promiss in
                        GADUtil.share.show(.back) { _ in
                            promiss(.success(.pop))
                        }
                    }
                    return .publisher {
                        publisher
                    }
                } else {
                    return .run { send in
                        await send(.pop)
                    }
                }
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
        NotificationHelper.shared.deleteNotifications(item)
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
}

struct ReminderView: View {
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
            }.onAppear(perform: {
                Request.tbaRequest(event: .backShow)
                if CacheUtil.shared.isUserGo {
                    GADUtil.share.load(.back)
                }
                viewStore.items.forEach {
                    NotificationHelper.shared.appendReminder($0)
                }
                Request.tbaRequest(event: .reminder)
            })
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        viewStore.send(.showAD)
                        Request.tbaRequest(event: .back)
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
            }
        }.background(Color("#F3F8FB").ignoresSafeArea())
    }
}
