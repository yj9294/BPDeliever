//
//  TrackerView.swift
//  BPDeliverer
//
//  Created by yangjian on 2023/12/1.
//

import SwiftUI
import Combine
import ComposableArchitecture
import AppTrackingTransparency

struct TrackerReducer: Reducer {
    struct State: Equatable {
        
        @UserDefault("measures", defaultValue: [])
        var measures: [Measurement]
        
        @UserDefault("top.mode", defaultValue: .last)
        var topMode: MeasureTopMode
        
        var filterDuration: DateDuration = .init()
        
        var adModel: GADNativeViewModel = .none
    }
    
    enum Action: Equatable {
        case updateIsGuide(Bool)
        case filterDateLastTapped
        case filterDateNextTapped
        case filterDateMinTapped
        case filterDateMaxTapped
        case showTrackerAD
        case updateTopMode(MeasureTopMode)
        case addButtonTapped
    }
    var body: some Reducer<State, Action> {
        Reduce{ state, action in
            switch action{
            case .filterDateLastTapped:
                state.lastFilterDate()
            case .filterDateNextTapped:
                state.nextFilterDate()
            case let .updateTopMode(mode):
                state.topMode = mode
            default:
                break
            }
            return .none
        }
    }
}

extension TrackerReducer.State {
    
    var filterMeasures: [Measurement] {
        measures.filter { measure in
            measure.date > filterDuration.min.exactlyDay && measure.date < filterDuration.max.exactlyDay
        }
    }
    
    var lastMeasure: Measurement {
        topMode == .last ? (measures.first ?? Measurement()) : avgMeasure
    }
    
    var avgMeasure: Measurement {
        let measures = measures.filter { measure in
            Date().timeIntervalSince1970 -  measure.date.timeIntervalSince1970 < 30 * 24 * 3600
        }
        let sys = measures.map({$0.systolic}).reduce(0, +)
        let dia = measures.map({$0.diastolic}).reduce(0, +)
        let pul = measures.map({$0.pulse}).reduce(0, +)
        if measures.isEmpty {
            return Measurement(systolic: 0, diastolic: 0, pulse: 0)
        } else {
            return Measurement(systolic: sys / measures.count, diastolic: dia / measures.count, pulse: pul / measures.count)
        }
    }
    
    var hasAD: Bool {
        adModel != .none
    }
    
    mutating func lastFilterDate() {
        filterDuration.max = filterDuration.max.addingTimeInterval(-.weak)
        filterDuration.min = filterDuration.min.addingTimeInterval(-.weak)
    }
    mutating func nextFilterDate() {
        filterDuration.max = filterDuration.max.addingTimeInterval(.weak)
        filterDuration.min = filterDuration.min.addingTimeInterval(.weak)
    }
}


struct TrackerView: View {
    let store: StoreOf<TrackerReducer>
    var body: some View {
        WithViewStore(store, observe: {$0}) { viewStore in
            ZStack{
                VStack{
                    MeasurementView(store: store)
                    Spacer()
                    if viewStore.hasAD {
                        HStack{
                            GADNativeView(model: viewStore.adModel)
                        }.frame(height: 136).padding(.horizontal, 20).padding(.bottom, 20)
                    } else {
                        Spacer().frame(height: 136)
                    }
                }
            }.onAppear {
                Request.tbaRequest(event: .track)
                Request.tbaRequest(event: .trackerAD)
                Request.tbaRequest(event: .trackerADShow)
                GADUtil.share.load(.log)
            }
        }.background(Color("#F3F8FB")).onAppear {
            ATTrackingManager.requestTrackingAuthorization { _ in
            }
        }
    }
    
    struct MeasurementView: View {
        let store: StoreOf<TrackerReducer>
        var body: some View {
            WithViewStore(store, observe: {$0}) { viewStore in
                VStack(spacing: 38){
                    MeasurementContentView(store: store).padding(.top, 12)
                    MeasurementButtonView(store: store)
                }.padding(.horizontal, 20)
            }
        }
    }
    
    struct MeasurementContentView: View {
        let store: StoreOf<TrackerReducer>
        var body: some View {
            WithViewStore(store, observe: {$0}) { viewStore in
                VStack(spacing: 14){
                    HStack{
                        if viewStore.topMode == .avg {
                            Text("48 Hours average").foregroundStyle(Color.white).font(.system(size: 14.0))
                        } else {
                            Text(viewStore.lastMeasure.date.detail).foregroundStyle(.white).font(.system(size: 12))
                        }
                        Spacer()
                        TopButtonView(mode: viewStore.topMode) { mode in
                            viewStore.send(.updateTopMode(mode))
                        }
                    }.padding(.vertical, 11)
                    HStack{
                        VStack(spacing: 16){
                            MeasurementLabelView(value: viewStore.lastMeasure.systolic, item: .systolic)
                            MeasurementLabelView(value: viewStore.lastMeasure.diastolic, item: .diastolic)
                            MeasurementLabelView(value: viewStore.lastMeasure.pulse, item: .pulse)
                        }.frame(width: 130)
                        Spacer()
                        if viewStore.topMode == .last {
                            VStack{
                                MeasurementDetailView(measure: viewStore.lastMeasure)
                            }.padding(.top, 157)
                        }
                    }.padding(.bottom, 20)
                }.padding(.horizontal, 16).background(Image("tracker_content").resizable()).shadow
            }
        }
    }
    
    struct MeasurementDetailView: View {
        let measure: Measurement
        var body: some View {
            VStack(alignment: .leading, spacing: 5){
                Text(measure.status.title).foregroundStyle(.white).padding(.horizontal, 9).padding(.vertical, 4).background(.linearGradient(colors: [Color(uiColor: measure.status.color), Color(uiColor: measure.status.endColor)], startPoint: .leading, endPoint: .trailing)).cornerRadius(13)
                HStack(spacing: 6){
                    ForEach(measure.posture, id:\.self) { item in
                        if case let Measurement.Posture.feeel(feel) = item {
                            Image(feel.icon)
                        }
                        if case let Measurement.Posture.arm(feel) = item {
                            Image(feel.icon)
                        }
                        if case let Measurement.Posture.body(feel) = item {
                            Image(feel.icon)
                        }
                    }
                }
            }.padding(.all, 10).background(Image("tracker_detail").resizable())
        }
    }
    
    struct MeasurementLabelView: View {
        let value: Int?
        let item: Measurement.BloodPressure
        var body: some View {
            HStack{
                Text("\(value ?? 0)").foregroundStyle(Color("#194D54")).font(.system(size: 28))
                Spacer()
                Text("(\(item.unit))").foregroundStyle(Color("#194D54")).font(.system(size: 11))
            }.padding(.all, 12).frame(height: 64).background(.white).cornerRadius(8)
        }
    }
    
    struct MeasurementButtonView: View {
        let store: StoreOf<TrackerReducer>
        var body: some View {
            WithViewStore(store, observe: {$0}) { viewStore in
                Button {
                    viewStore.send(.addButtonTapped)
                    Request.tbaRequest(event: .trackAdd)
                } label: {
                    HStack(spacing: 7){
                        Spacer()
                        Image("guide_add")
                        Text("Add").foregroundStyle(.white).font(.system(size: 16.0)).padding(.vertical, 15)
                        Spacer()
                    }
                }.background(.linearGradient(colors: [Color("#FFB985"), Color("#F89042")], startPoint: .leading, endPoint: .trailing)).cornerRadius(26).padding(.horizontal, 70)
            }
        }
    }
    
    struct DateView: View {
        let store: StoreOf<TrackerReducer>
        var body: some View {
            WithViewStore(store, observe: {$0}) { viewStore in
                HStack(spacing: 10){
                    Button(action: {viewStore.send(.filterDateLastTapped)}, label: {Image("tracker_last")})
                    HStack(spacing: 0){
                        Button(action: {viewStore.send(.filterDateMinTapped)}, label: {
                            Text(viewStore.filterDuration.min.day)
                        })
                        Text(" ~ ")
                        Button(action: {viewStore.send(.filterDateMaxTapped)}, label: {
                            Text(viewStore.filterDuration.max.day)
                        })
                    }.font(.system(size: 12)).foregroundColor(Color("#BBCDD9")).padding(.all, 10).shadow
                    Button(action: {viewStore.send(.filterDateNextTapped)}, label: {Image("tracker_next")})
                }
            }
        }
    }
    
    struct TrackerCell: View {
        let measure: Measurement
        let topMode: MeasureTopMode
        let isTop: Bool
        var action: ((MeasureTopMode)->Void)? = nil
        
        var body: some View {
            VStack(spacing: 0){
                HStack{
                    if isTop, topMode == .avg {
                        Text("48 Hours average").foregroundStyle(Color.white).font(.system(size: 14.0))
                    } else {
                        HStack(spacing: 8){
                            Image(isTop ? "tracker_date_top" : "tracker_date")
                            Text(measure.date.detail).foregroundStyle(isTop ? Color.white : Color("#BBCDD9")).font(.system(size: 12))
                        }
                    }
                    Spacer()
                    if isTop {
                        TopButtonView(mode: topMode, action: action)
                    }
                }.padding(.all, 14).background(LinearGradient.linearGradient(colors: [Color("#42C3D6"), Color("#5AE9FF")], startPoint: .leading, endPoint: .trailing).clipShape(CustomRoundedRectangle(topLeftRadius: 8, topRightRadius: 8, bottomLeftRadius: 0, bottomRightRadius: 0)).opacity(isTop ? 1.0 : 0.0))
                Color("#E9F0F5").frame(height: 1).padding(.horizontal, 12)
                VStack(spacing: 4){
                    HStack{
                        HStack(alignment: .bottom, spacing: 6){
                            Text(verbatim: "\(measure.systolic)/\(measure.diastolic)").font(.system(size: 32)).foregroundStyle(Color("#194D54"))
                            Text("mmHg").foregroundStyle(Color("#BBCDD9")).font(.system(size: 11)).padding(.bottom, 6)
                        }
                        Spacer()
                        HStack(spacing: 6){
                            Image("tracker_heart")
                            HStack(alignment: .bottom){
                                Text(verbatim: "\(measure.pulse)").font(.system(size: 32)).foregroundStyle(Color("#194D54"))
                                Text("BPM").foregroundStyle(Color("#BBCDD9")).font(.system(size: 11)).padding(.bottom, 6)
                            }
                        }
                    }
                    if isTop, topMode == .avg {
                        Spacer().frame(height: 1)
                    } else {
                        HStack{
                            Text(LocalizedStringKey(measure.status.title)).padding(.vertical,4).padding(.horizontal, 9).background(.linearGradient(colors: [Color(uiColor: measure.status.color), Color(uiColor: measure.status.endColor)], startPoint: .leading, endPoint: .trailing)).cornerRadius(13).foregroundColor(.white).font(.system(size: 14.0))
                            Spacer()
                            HStack(spacing: 0){
                                ForEach(measure.posture, id:\.self) { item in
                                    if case let Measurement.Posture.feeel(feel) = item {
                                        Image(feel.icon)
                                    }
                                    if case let Measurement.Posture.arm(feel) = item {
                                        Image(feel.icon)
                                    }
                                    if case let Measurement.Posture.body(feel) = item {
                                        Image(feel.icon)
                                    }
                                }
                            }
                        }
                    }
                }.padding(.vertical, (isTop && topMode == .avg) ? 25 : 12).padding(.horizontal, 14)
            }
        }
    }
    
    struct TopButtonView: View {
        let mode: MeasureTopMode
        var action: ((MeasureTopMode)->Void)? = nil
        var body: some View {
            HStack(spacing: 0){
                ItemButtonView(title: MeasureTopMode.last.title, isSelected: mode == .last) {
                    action?(.last)
                }
                ItemButtonView(title: MeasureTopMode.avg.title, isSelected: mode == .avg) {
                    action?(.avg)
                }
            }.padding(.all, 2).background(Color("#FFEFE3").cornerRadius(16.0))
        }
        
        struct ItemButtonView: View {
            let title: String
            let isSelected: Bool
            let action: ()->Void
            var body: some View {
                Button(action: action, label: {
                    Text(title).foregroundStyle(isSelected ? Color.white : Color("#C8B8AC")).font(.system(size: 12)).padding(.vertical, 7).padding(.horizontal, 12)
                }).background(isSelected ? Color("#F89042").cornerRadius(14) : Color.clear.cornerRadius(0))
            }
        }
    }
}

enum MeasureTopMode: String,Codable {
   case last, avg
    
    var title: String {
        return self.rawValue.capitalized
    }
}
