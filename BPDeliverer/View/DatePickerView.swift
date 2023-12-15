//
//  DatePickerView.swift
//  BPDeliverer
//
//  Created by yangjian on 2023/12/9.
//

import Foundation
import SwiftUI
import ComposableArchitecture

struct DatePickerReducer: Reducer {
    struct State: Equatable {
        @BindingState var date: Date
        let postion: Position
        let components: DatePickerComponents
    }
    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case ok(Date,State.Position)
        case cancel
    }
    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce{ state, action in
            return .none
        }
    }
}

extension DatePickerReducer.State {
    enum Position {
        case filterMin, filterMax, newReminder, newMeasure
    }
}

struct DatePickerView: View {
    let store: StoreOf<DatePickerReducer>
    var body: some View {
        WithViewStore(store, observe: {$0}) { viewStore in
            VStack{
                HStack{Spacer()}
                Spacer()
                VStack(spacing: 20){
                    Text(LocalizedStringKey("Selection period")).font(.system(size: 20)).foregroundStyle(.black)
                    DatePicker("", selection: viewStore.$date, displayedComponents: viewStore.components).datePickerStyle(.wheel).labelsHidden()
                    Button(action: {viewStore.send(.ok(viewStore.date, viewStore.postion))}) {
                        Text(LocalizedStringKey("OK")).frame(width: 220, height: 50).background(Color("#42C3D6")).cornerRadius(25).foregroundColor(.white)
                    }
                }.padding(.all, 22).background(.white).cornerRadius(16)
                Spacer()
            }.background(Color.black.opacity(0.3).ignoresSafeArea().onTapGesture {
                viewStore.send(.cancel)
            })
        }
        
    }
}
