//
//  NewView.swift
//  BPDeliverer
//
//  Created by yangjian on 2023/12/1.
//

import SwiftUI
import ComposableArchitecture

struct AddReducer: Reducer {
    struct State: Equatable {
        init(root: RootReducer.State) {
            self.root = root
        }
        var path: StackState<Path.State> = .init()
        var root: RootReducer.State = .init(measure: .init(), status: .new, adModel: .none)
        
        @PresentationState var datePicker: DatePickerReducer.State? = nil
        
    }
    enum Action: Equatable {
        case path(StackAction<Path.State, Path.Action>)
        case root(RootReducer.Action)
        case datePicker(PresentationAction<DatePickerReducer.Action>)
    }
    var body: some Reducer<State, Action> {
        Reduce{ state, action in
            if case .root(.continueButtonTapped) = action {
                state.pushEditView()
                Request.tbaRequest(event: .addContinue)
            }
            if case .path(.element(id: _, action: .edit(.pop))) = action {
                state.popEditView()
            }
            if case .path(.element(id:_, action: .edit(.dateButtonTapped))) = action {
                state.presentDatePickerView()
            }
            if case .datePicker(.presented(.cancel)) = action {
                state.dismissDatePickerView()
            }
            if case let .datePicker(.presented(.ok(date, _))) = action {
                state.updateMeasureDate(date)
                state.dismissDatePickerView()
            }
            if case .root(.dismiss) = action {
                Request.tbaRequest(event: .addDismiss)
            }
            
            return .none
        }.forEach(\.path, action: /Action.path) {
            Path()
        }.ifLet(\.$datePicker, action: /Action.datePicker) {
            DatePickerReducer()
        }
        
        Scope(state: \.root, action: /Action.root) {
            RootReducer()
        }
    }
    
    struct Path: Reducer {
        enum State: Equatable {
            case edit(EditReducer.State)
        }
        enum Action: Equatable {
            case edit(EditReducer.Action)
        }
        var body: some Reducer<State, Action> {
            Reduce{ state, action in
                return .none
            }
            Scope(state: /State.edit, action: /Action.edit) {
                EditReducer()
            }
        }
    }
    
    struct RootReducer: Reducer {
        struct State: Equatable {
            @BindingState var measure: Measurement
            let status: Status
            var adModel: GADNativeViewModel = .none
            enum Status {
                case new, edit
            }
            var hasAD: Bool {
                adModel != .none
            }
        }
        enum Action: BindableAction, Equatable {
            case dismiss
            case binding(BindingAction<State>)
            case continueButtonTapped
            case showAD
        }
        var body: some Reducer<State, Action> {
            BindingReducer()
            Reduce{ state, action in
                if case .continueButtonTapped = action {
                    GADUtil.share.disappear(.add)
                }
                return .none
            }
        }
    }
    
}

extension AddReducer.State {
    
    mutating func pushEditView() {
        path.append(.edit(.init(measure: root.measure)))
    }
    mutating func popEditView() {
        path.removeAll()
    }
    
    mutating func presentDatePickerView() {
        if root.status == .edit {
            return
        }
        datePicker = .init(date: Date(), postion: .newMeasure, components: [.date, .hourAndMinute])
    }
    mutating func dismissDatePickerView() {
        datePicker = nil
    }
    
    mutating func updateMeasureDate(_ date: Date) {
        root.measure.date = date
    }
    
}

struct AddView: View {
    let store: StoreOf<AddReducer>
    var body: some View {
        NavigationStackStore(store.scope(state: \.path, action: {.path($0)})) {
            RootView(store: store.scope(state: \.root, action: AddReducer.Action.root))
                .fullScreenCover(store: store.scope(state: \.$datePicker, action: {.datePicker($0)})) { store in
                    DatePickerView(store: store).background(BackgroundClearView())
                }
        } destination: {
            switch $0 {
            case .edit:
                CaseLet(/AddReducer.Path.State.edit, action: AddReducer.Path.Action.edit, then: EditView.init(store:))
            }
        }.navigationBarBackButtonHidden().navigationBarTitleDisplayMode(.inline)
    }
    
    struct RootView: View {
        let store: StoreOf<AddReducer.RootReducer>
        var body: some View {
            WithViewStore(store, observe: {$0}) { viewStore in
                VStack{
                    MeasurementView(measure: viewStore.$measure).padding(.horizontal, 20).padding(.vertical, 16)
                    ButtonView {
                        viewStore.send(.continueButtonTapped)
                        
                    }
                    if viewStore.hasAD {
                        HStack{
                            GADNativeView(model: viewStore.adModel)
                        }.frame(height: 136).padding(.horizontal, 20)
                    }
                    Spacer()
                }.toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            viewStore.send(.dismiss)
                        } label: {
                            Image("add_back")
                        }
                    }
                }.navigationTitle(LocalizedStringKey("New Measurement")).navigationBarTitleDisplayMode(.inline)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            viewStore.send(.showAD)
                        }
                        Request.tbaRequest(event: .add)
                    }
            }
        }
        
        struct MeasurementView:View {
            @Binding var measure: Measurement
            var body: some View {
                VStack{
                    HStack{Spacer()}
                    MenuView().padding(.top, 16)
                    ContentView(measure: $measure)
                }.background(.white).cornerRadius(8).shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
            }
            
            struct MenuView: View {
                var body: some View {
                    HStack{
                        MenuCell(item: .systolic).frame(width: 80)
                        Spacer()
                        MenuCell(item: .diastolic).frame(width: 80)
                        Spacer()
                        MenuCell(item: .pulse).frame(width: 80)
                    }
                }
                
                struct MenuCell: View {
                    let item: Measurement.BloodPressure
                    var body: some View {
                        HStack{
                            Spacer()
                            VStack{
                                Text(LocalizedStringKey(item.title)).foregroundStyle(Color("#59D5E7")).font(.system(size: 16))
                                Text(item.unit).foregroundStyle(Color("#CBCCCF")).font(.system(size: 12))
                            }
                            Spacer()
                        }
                    }
                }
            }
            
            struct ContentView: View {
                @Binding var measure: Measurement
                var body: some View {
                    HStack{
                        PickerView(selection: $measure, datasource: measure.datasource)
                    }.frame(height: 240)
                }
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
                        Text(LocalizedStringKey("Continue")).foregroundStyle(.white)
                    }
                }
            }
        }
    }
}

struct PickerView: View {
    @Binding var selection: Measurement
    var datasource: [[Int]]
    var body: some View {
        Picker(selection: $selection, datasource: datasource)
    }
}

struct Picker: UIViewRepresentable {
    
    @Binding var selection: Measurement
    var datasource: [[Int]]
    
    func makeUIView(context: Context) -> some UIView {
        let view = UIPickerView()
        view.dataSource = context.coordinator
        view.delegate = context.coordinator
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            view.selectRow(selection.systolic - 30, inComponent: 0, animated: false)
            view.selectRow(selection.diastolic - 30, inComponent: 1, animated: false)
            view.selectRow(selection.pulse - 30, inComponent: 2, animated: false)
        }
        return view
    }
    func updateUIView(_ uiView: UIViewType, context: Context) {
        if let view = uiView as? UIPickerView, view.numberOfComponents > 0 {
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(preview: self)
    }
    
    class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
        func numberOfComponents(in pickerView: UIPickerView) -> Int {
            preview.datasource.count
        }
        
        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            preview.datasource[component].count
        }
        
        func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
            50
        }
        
        func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
            let w = pickerView.window?.frame.width ?? 375.0
            return (w - 40) / 3.0
        }
        
        func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
            let label = UILabel()
            label.attributedText = NSMutableAttributedString(string: "\(preview.datasource[component][row])",attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 35), NSAttributedString.Key.foregroundColor: UIColor.black])
            label.textAlignment = .center
            return label
        }
        
        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            if component == 0 {
                preview.selection.systolic = preview.datasource[component][row]
            } else if component == 1 {
                preview.selection.diastolic = preview.datasource[component][row]
            } else if component == 2 {
                preview.selection.pulse = preview.datasource[component][row]
            }
        }
        
        let preview: Picker
        init(preview: Picker) {
            self.preview = preview
        }
    }
    
}

