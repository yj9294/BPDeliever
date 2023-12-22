//
//  LaunchView.swift
//  BPDeliverer
//
//  Created by yangjian on 2023/12/1.
//

import SwiftUI
import Combine
import ComposableArchitecture

struct LaunchReducer: Reducer {
    enum CancelID { case progress}
    struct State: Equatable {
        var progress = 0.0
        var duration = 12.5
        var isLaunched: Bool {
            progress >= 1.0
        }
        var isStart = false
    }
    enum Action: Equatable {
        case start
        case stop
        case update
        case launched
        case showAD
    }
    var body: some Reducer<State, Action> {
        Reduce{ state, action in
            switch action {
            case .start:
                if state.isStart {
                    return .none
                }
                state.initProgress()
                state.startCloakRequest()
                GADPosition.allCases.filter({ po in
                    po != .enter && po != .back
                }).forEach({
                    GADUtil.share.load($0)
                })
                return .publisher {
                    Timer.publish(every: 0.01, on: .main, in: .common).autoconnect().map({_ in Action.update})
                }.cancellable(id: CancelID.progress)
            case .stop:
                state.isStart = false
                return .cancel(id: CancelID.progress)
            case .update:
                state.updateProgress()
                if GADUtil.share.isLoaded(.loading), state.progress > 0.3 {
                    state.updateDuration()
                }
                if state.isLaunched {
                    return .run { send in
                        await send(.stop)
                        try await Task.sleep(nanoseconds: 500_000_000)
                        await send(.showAD)
                    }
                }
            case .showAD:
                Request.tbaRequest(event: .loadingShow)
                let publisher = Future<Action, Never>{ promiss in
                    GADUtil.share.show(.loading) { _ in
                        promiss(.success(.launched))
                    }
                }
                return .publisher {
                    publisher
                }
            default:
                break
            }
            return .none
        }
    }
    
    
}

extension LaunchReducer.State {
    func startCloakRequest() {
        Request.cloakRequest()
        Request.tbaRequest(event: .loading)
    }
    mutating func initProgress() {
        isStart = true
        progress = 0.0
        duration = 12.5
    }
    mutating func updateProgress() {
        progress += 0.01 / duration
        if progress >= 1.0 {
            progress = 1.0
        }
    }
    mutating func updateDuration() {
        duration = 0.3
    }
}

struct LaunchView: View {
    let store: StoreOf<LaunchReducer>
    @Environment(\.scenePhase) var scenePhase
    var body: some View {
        WithViewStore(store, observe: {$0}) { viewStore in
            VStack{
                Image("BP Deliverer").padding(.top, 110)
                Spacer()
                ProgressView(value: viewStore.progress).tint(.white).padding(.bottom, 43).padding(.horizontal, 80)
            }.background(Image("bg") .resizable().ignoresSafeArea()).onReceive(coldOpenPublisher) { _ in
                viewStore.send(.start)
            }.onChange(of: scenePhase) { state in
                if case .inactive = state {
                    viewStore.send(.stop)
                }
                if case .active = state {
                    viewStore.send(.start)
                }
            }
        }
    }
}
