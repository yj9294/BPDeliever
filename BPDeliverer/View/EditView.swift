//
//  EditView.swift
//  BPDeliverer
//
//  Created by yangjian on 2023/12/1.
//

import SwiftUI
import Combine
import ComposableArchitecture

struct EditReducer: Reducer {
    struct State: Equatable {
        @BindingState var measure: Measurement
        mutating func itemSelected(_ item: String, posture: Measurement.Posture) {
            switch posture {
            case .feeel:
                measure.posture[0] = .feeel(Measurement.Posture.Feel(rawValue: item) ?? .happy)
            case .arm:
                measure.posture[1] = .arm(Measurement.Posture.Hands(rawValue: item) ?? .left)
            case .body:
                measure.posture[2] = .body(Measurement.Posture.Body(rawValue: item) ?? .lying)
            }
        }
    }
    enum Action: BindableAction, Equatable {
        case pop
        case binding(BindingAction<State>)
        case itemSelected(String, Measurement.Posture)
        case buttonTapped(Measurement)
        case dateButtonTapped
        case showAD
    }
    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case let .itemSelected(item, posture):
                state.itemSelected(item, posture: posture)
            case .showAD:
                GADUtil.share.load(.submit)
                let publisher = Future<Action, Never> { [measure = state.measure] promise in
                    GADUtil.share.show(.submit) { _ in
                        promise(.success(.buttonTapped(measure)))
                    }
                }
                return .publisher {
                    publisher
                }
            case .pop:
                Request.tbaRequest(event: .addPop)
            default:
                break
            }
            return .none
        }
    }
}


struct EditView: View {
    let store: StoreOf<EditReducer>
    var body: some View {
        WithViewStore(store, observe: {$0}) { viewStore in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18){
                    MeasureView(store: store)
                    DateView(store: store)
                    PostureView(store: store)
                    NoteView(measure: viewStore.$measure, enable: true)
                    ButtonView {
                        CacheUtil.shared.updateNotiAlertAddMeasureCount()
                        viewStore.send(.showAD)
                        Request.tbaRequest(event: .save)
                        Request.tbaRequest(event: .addSave)
                        Request.tbaRequest(event: .addEditSave)
//                        Request.tbaRequest(event: .addFeel)
//                        Request.tbaRequest(event: .addArm)
//                        Request.tbaRequest(event: .addBody)
//                        if !viewStore.measure.note.isEmpty {
//                            Request.tbaRequest(event: .addNote)
//                        }
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, 20)
            .background(Color("#F3F8FB").ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        viewStore.send(.pop)
                    } label: {
                        Image("add_back")
                    }
                }
            }.navigationTitle(LocalizedStringKey("Edit")).navigationBarTitleDisplayMode(.inline).navigationBarBackButtonHidden()
        }
    }
    
    struct MeasureView: View {
        let store: StoreOf<EditReducer>
        var body: some View {
            WithViewStore(store, observe: {$0}) { viewStore in
                VStack{
                    VStack(alignment: .leading, spacing: 16){
                        HStack(alignment: .bottom){
                            HStack(alignment: .bottom, spacing: 6){
                                Text(verbatim: "\(viewStore.measure.systolic)/\(viewStore.measure.diastolic)").font(.system(size: 32))
                                Text("mmHg").foregroundStyle(Color("#BBCDD9")).font(.system(size: 11)).padding(.bottom,6)
                            }
                            Spacer()
                            HStack(spacing: 8){
                                Image("edit_heart")
                                HStack(alignment: .bottom, spacing: 2){
                                    Text(verbatim: "\(viewStore.measure.pulse)").font(.system(size: 32))
                                    Text("BPM").foregroundStyle(Color("#BBCDD9")).font(.system(size: 11)).padding(.bottom,6)
                                }
                            }
                        }
                        Text(LocalizedStringKey("Range: " + viewStore.measure.status.title)).font(.system(size: 14)).foregroundStyle(Color("#BBCDD9"))
                    }.padding(.vertical, 12).padding(.horizontal, 14).background(Color.white.cornerRadius(8).shadow(color: .black.opacity(0.07), radius: 4, x: 0, y: 2))
                }
            }.padding(.top, 16)
        }
    }
    
    struct DateView: View {
        let store: StoreOf<EditReducer>
        var body: some View {
            WithViewStore(store, observe: {$0}) { viewStore in
                Button {
                    viewStore.send(.dateButtonTapped)
                } label: {
                    VStack{
                        HStack(spacing: 20){
                            Text(viewStore.measure.date.detail).foregroundStyle(Color("#BBCDD9")).font(.system(size: 12.0))
                            Image("edit_edit")
                        }
                    }
                }.padding(.vertical, 10).padding(.horizontal, 12).shadow
            }
        }
    }
    
    struct PostureView: View {
        let store: StoreOf<EditReducer>
        var body: some View {
            WithViewStore(store, observe: {$0}) { viewStore in
                VStack{
                    ForEach(viewStore.measure.posture, id: \.self) { item in
                        StatusCell(store: store, posture: item)
                    }
                }.padding(.vertical, 20).padding(.horizontal, 16).shadow
            }
        }
        
        struct StatusCell: View {
            let store: StoreOf<EditReducer>
            let posture: Measurement.Posture
            var body: some View {
                WithViewStore(store, observe: {$0}) { viewStore in
                    HStack{
                        Text(LocalizedStringKey(posture.title)).foregroundStyle(Color("#59D5E7")).font(.system(size: 16, weight: .medium))
                        Spacer()
                        HStack(spacing: 20){
                            ForEach(posture.selectSource, id:\.self) { item in
                                VStack{
                                    Image("edit_" + item)
                                    Image("edit_selected").opacity(isSelected(in: viewStore.state, item: item) ? 1.0 : 0.0)
                                }.onTapGesture {
                                    viewStore.send(.itemSelected(item, posture))
                                }
                            }
                        }
                    }
                }
            }
            
            func isSelected(in viewStore: EditReducer.State, item: String) -> Bool {
                let np = viewStore.measure.posture.filter { p in
                    p == posture
                }.first
                switch np {
                case let .feeel(feel):
                    return feel.rawValue == item
                case let .arm(arm):
                    return arm.rawValue == item
                case let .body(body):
                    return body.rawValue == item
                case .none:
                    return false
                }
            }
            
        }
    }
    
    struct NoteView: View {
        @Binding var measure: Measurement
        let enable: Bool
        var body: some View {
            VStack(alignment: .leading){
                HStack{ Spacer() }
                HStack{
                    Image("edit_note")
                    Text(LocalizedStringKey("Note"))
                }
                TextField("", text: $measure.note, prompt: Text(LocalizedStringKey("Mabel Figueroa Hattie Fitzgerald Nancy Ball Mabel Figueroa")), axis: .vertical).disabled(!enable).frame(height: 44).lineLimit(2)        .onReceive(Just(measure.note)) { _ in measure.note = String(measure.note.prefix(100)) }
            }
            .foregroundColor(Color("#BBCDD9")).font(.system(size: 12)).padding(.vertical, 12).padding(.horizontal, 14).shadow
        }
    }
    
    struct ButtonView: View {
        let action: ()->Void
        var body: some View {
            Button {
                action()
            } label: {
                ZStack{
                    Image("add_button_bg")
                    Text(LocalizedStringKey("OK")).foregroundStyle(.white)
                }
            }
        }
    }
}
