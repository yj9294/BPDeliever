//
//  ProfileView.swift
//  BPDeliverer
//
//  Created by yangjian on 2023/12/1.
//

import SwiftUI
import ComposableArchitecture

struct ProfileReducer: Reducer {
    struct State: Equatable {
        let items = Item.allCases
        var adModel: GADNativeViewModel = .none
    }
    enum Action: Equatable {
        case itemDidSelected(State.Item)
        case reminderButtonTapped
        case  privacyButtonTapped
        case languageButtonTapped
        case showAD
    }
    var body: some Reducer<State, Action> {
        Reduce{ state, action in
            if case let .itemDidSelected(item) = action {
                switch item {
                case .reminder:
                    return .run { send in
                        await send(.reminderButtonTapped)
                    }
                case .privacy:
                    return .run { send in
                        await send(.privacyButtonTapped)
                    }
                case .language:
                    return .run { send in
                        await send(.languageButtonTapped)
                    }
                case .contact:
                    let AppUrl = "https://itunes.apple.com/cn/app/id"
                    OpenURLAction { URL in
                        .systemAction(URL)
                    }.callAsFunction(URL(string: AppUrl)!)
                }
            }
            return .none
        }
    }
}

extension ProfileReducer.State {
    enum Item: String, CaseIterable {
        case reminder, privacy, language, contact
        var icon: String {
            return "profile_" + self.rawValue
        }
        var title: String {
            switch self {
            case .reminder:
                return "Daily reminder"
            case .privacy:
                return "Privacy policy"
            case .language:
                return "Language"
            case .contact:
                return "Contact us"
            }
        }
    }
    var hasAD: Bool {
        adModel != .none
    }
}

struct ProfileView: View {
    let store: StoreOf<ProfileReducer>
    var body: some View {
        WithViewStore(store, observe: {$0}) { viewStore in
            VStack{
                ScrollView{
                    LazyVGrid(columns: [GridItem(.flexible())], spacing: 12) {
                        ForEach(viewStore.items, id: \.self) { item in
                            Button {
                                viewStore.send(.itemDidSelected(item))
                            } label: {
                                HStack{
                                    HStack(spacing: 14){
                                        Image(item.icon)
                                        Text(LocalizedStringKey(item.title)).foregroundStyle(.black).font(.system(size: 16))
                                        Spacer()
                                        Image("arrow")
                                    }.padding(.all, 22).shadow
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }.padding(.top, 40)
                }
                if viewStore.hasAD {
                    HStack{
                        GADNativeView(model: viewStore.adModel)
                    }.frame(height: 136).padding(.horizontal, 20).padding(.bottom, 24)
                }
            }.onAppear {
                viewStore.send(.showAD)
                Request.tbaRequest(event: .setting)
            }
        }.background(Color("#F3F8FB").ignoresSafeArea())
    }
}
