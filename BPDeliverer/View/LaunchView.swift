//
//  LaunchView.swift
//  BPDeliverer
//
//  Created by yangjian on 2023/12/1.
//

import SwiftUI
import ComposableArchitecture

struct LaunchReducer: Reducer {
    enum CancelID { case progress}
    struct State: Equatable {
        var progress = 0.0
        var duration = 2.5
        var isLaunched: Bool {
            progress >= 1.0
        }
    }
    enum Action: Equatable {
        case start
        case stop
        case update
    }
    var body: some Reducer<State, Action> {
        Reduce{ state, action in
            switch action {
            case .start:
                state.initProgress()
                return .publisher {
                    Timer.publish(every: 0.01, on: .main, in: .common).autoconnect().map({_ in Action.update})
                }.cancellable(id: CancelID.progress)
            case .stop:
                return .cancel(id: CancelID.progress)
            case .update:
                state.updateProgress()
            }
            return .none
        }
    }
}

extension LaunchReducer.State {
    mutating func initProgress() {
        progress = 0.0
        duration = 2.5
    }
    mutating func updateProgress() {
        progress += 0.01 / duration
        if progress >= 1.0 {
            progress = 1.0
        }
    }
}

struct LaunchView: View {
    let store: StoreOf<LaunchReducer>
    var body: some View {
        WithViewStore(store, observe: {$0}) { viewStore in
            VStack{
                Image("BP Deliverer").padding(.top, 110)
                Spacer()
                ProgressView(value: viewStore.progress).tint(.white).padding(.bottom, 43).padding(.horizontal, 80)
            }.background(Image("bg") .resizable().ignoresSafeArea())
        }
    }
}

