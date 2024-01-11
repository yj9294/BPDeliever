//
//  NotificationAlertView.swift
//  BPDeliverer
//
//  Created by yangjian on 2024/1/10.
//

import Foundation
import SwiftUI

import ComposableArchitecture

struct NotificationAlertReducer: Reducer {
    struct State: Equatable {}
    enum Action: Equatable {
        case dismiss
        case gotoSetting
    }
    var body: some Reducer<State, Action> {
        Reduce{ state, action in
            if case .gotoSetting = action {
                state.gotoSetting()
            }
            if case .dismiss = action {
                state.dismiss()
            }
            return .none
        }
    }
}

extension NotificationAlertReducer.State {
    func gotoSetting() {
        Request.tbaRequest(event: .notificationAlertGoSetting)
        guard let urlString = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        UIApplication.shared.open(urlString, options: [:]) { ret in
            debugPrint("open settings result:\(ret)")
        }
    }
    
    func dismiss() {
        Request.tbaRequest(event: .notificationAlertSkip)
    }
}

struct NotificationAlertView: View {
    let store: StoreOf<NotificationAlertReducer>
    var body: some View {
        WithViewStore(store, observe: {$0}) { viewStore in
            ZStack{
                Color.black.opacity(0.7).ignoresSafeArea()
                VStack{
                    HStack{Spacer()}
                    Spacer()
                    VStack(spacing: 16){
                        Image("noti")
                        Text(LocalizedStringKey("noti_desc")).foregroundStyle(Color("#53545C")).font(.system(size: 16)).multilineTextAlignment(.center)
                        VStack(spacing: 12){
                            Button(action: {
                                viewStore.send(.gotoSetting)
                            }, label: {
                                HStack{
                                    Spacer()
                                    Text(LocalizedStringKey("Set it now")).foregroundStyle(.white).padding(.vertical, 15).lineLimit(nil).truncationMode(.tail)
                                    Spacer()
                                }
                            }).background(.linearGradient(colors: [Color("#42C3D6"), Color("#5AE9FF")], startPoint: .leading, endPoint: .trailing)).cornerRadius(26).padding(.horizontal, 32)
                            Button(action: {
                                viewStore.send(.dismiss)
                            }, label: {
                                Text(LocalizedStringKey("Skip")).foregroundStyle(Color("#B4B3B3"))
                            })
                        }.font(.system(size: 16))
                    }.padding(.all, 20).background(.white).cornerRadius(16)
                    Spacer()
                }.padding(.horizontal, 20)
            }
        }
    }
}

#Preview {
    NotificationAlertView(store: Store.init(initialState: NotificationAlertReducer.State(), reducer: {
        NotificationAlertReducer()
    }))
}
