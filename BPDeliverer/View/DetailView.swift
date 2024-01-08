//
//  DetailView.swift
//  BPDeliverer
//
//  Created by yangjian on 2023/12/1.
//

import SwiftUI
import ComposableArchitecture

struct DetailReducer: Reducer {
    struct State: Equatable {
        @BindingState var measure: Measurement
        @PresentationState var alert: AlertState<Action.Alert>? = nil
    }
    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case pop
        case deleteButtonTapped
        case editButtonTapped
        case delete
        case alert(PresentationAction<Alert>)
        enum Alert: Equatable {
            case delete
        }
    }
    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce{ state, action in
            if case action = Action.deleteButtonTapped {
                state.alertView()
                Request.tbaRequest(event: .trackDelete)
            }
            if case .editButtonTapped = action {
                Request.tbaRequest(event: .trackEdit)
            }
            if case action = Action.alert(.presented(.delete)) {
                return .run { send in
                    await send(.delete)
                }
            }
            return .none
        }.ifLet(\.alert, action: /Action.alert)
    }
}

extension DetailReducer.State {
    mutating func alertView() {
        alert = AlertState(title: {
            TextState(LocalizedStringKey("Tip"))
        }, actions: {
            ButtonState(role: .cancel) {
                TextState(LocalizedStringKey("Cancel"))
            }
            ButtonState (role: .destructive, action: .delete, label: {
                TextState(LocalizedStringKey("Delete"))
            })
        }, message: {
            TextState(LocalizedStringKey("Are you sure you want to delete this record？"))
        })
    }
}


struct DetailView: View {
    let store: StoreOf<DetailReducer>
    var body: some View {
        WithViewStore(store, observe: {$0}) { viewStore in
            VStack(spacing: 16){
                TrackerView.TrackerCell(measure: viewStore.measure, topMode: .last, isTop: false).shadow.padding(.top, 20)
                EditView.NoteView(measure: viewStore.$measure, enable: false)
                Spacer()
                VStack(spacing: 10){
                    DeleteButton{viewStore.send(.deleteButtonTapped)}
                    EditButton{viewStore.send(.editButtonTapped)}
                }.padding(.bottom, 40)
            }
            .alert(store: self.store.scope(state: \.$alert, action: DetailReducer.Action.alert))
            .padding(.horizontal, 20)
            .background(Color("#F3F8FB"))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        viewStore.send(.pop)
                    } label: {
                        Image("add_back")
                    }
                }
            }.navigationTitle(LocalizedStringKey("Details")).navigationBarTitleDisplayMode(.inline).navigationBarBackButtonHidden()
        }
    }
    
    struct DeleteButton: View {
        let action: ()->Void
        var body: some View {
            Button(action: action) {
                ZStack{
                    Image("detail_delete_bg")
                    Text("Delete").font(.system(size: 16)).foregroundStyle(.white)
                }
            }
        }
    }
    
    struct EditButton: View {
        let action: ()->Void
        var body: some View {
            Button(action: action) {
                ZStack{
                    Image("detail_edit_bg")
                    Text("Edit").font(.system(size: 16)).foregroundStyle(Color("#43C4D7"))
                }
            }
        }
    }
}
