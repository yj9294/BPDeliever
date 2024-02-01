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
        @UserDefault("guide", defaultValue: false)
        var isGuide: Bool
        
        @UserDefault("measures", defaultValue: [])
        var measures: [Measurement]
        
        @UserDefault("top.mode", defaultValue: .last)
        var topMode: MeasureTopMode
        
        var filterDuration: DateDuration = .init()
        
        var adModel: GADNativeViewModel = .none
        
        var showReadingGuide = false
    }
    enum Action: Equatable {
        case guide
        case filterDateLastTapped
        case filterDateNextTapped
        case filterDateMinTapped
        case filterDateMaxTapped
        case addButtonTapped
        case historyButtonTapped
        case showAD
        case showGuideAD
        case updateTopMode(MeasureTopMode)
        case updateShowReadingGuide(Bool)
        case okButtonTapped
    }
    var body: some Reducer<State, Action> {
        Reduce{ state, action in
            switch action{
            case .guide:
                state.isGuide = true
            case .filterDateLastTapped:
                state.lastFilterDate()
            case .filterDateNextTapped:
                state.nextFilterDate()
            case .addButtonTapped:
                return .run { send in
                    await send(.guide)
                }
            case .showGuideAD:
                let publisher = Future<Action, Never> { promiss in
                    GADUtil.share.load(.guide)
                    GADUtil.share.show(.guide) { _ in
                        promiss(.success(.addButtonTapped))
                    }
                }
                return .publisher {
                    publisher
                }
            case let .updateTopMode(mode):
                if mode != state.topMode {
                    GADUtil.share.load(.trackerExchange)
                    GADUtil.share.show(.trackerExchange)
                    Request.tbaRequest(event: .trackerExchange)
                }
                state.topMode = mode
            case let .updateShowReadingGuide(isShow):
                state.showReadingGuide = isShow
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
                // 方案判定
                if CacheUtil.shared.getMeasureGuide() == .a {
                    // a 方案是 一次安装首次打开
                    if !viewStore.isGuide {
                        GuideView {
                            viewStore.send(.showGuideAD)
                            Request.tbaRequest(event: .guideAdd)
                            Request.tbaRequest(event: .guideAd)
                        }
                    }
                } else {
                    // b 方案是每次打开判定是否有记录 没得记录都要弹出
                    if viewStore.measures.count == 0 {
                        GuideView {
                            viewStore.send(.showGuideAD)
                            Request.tbaRequest(event: .guideAdd)
                            Request.tbaRequest(event: .guideAd)
                        }
                    }
                }
                
                // reading 引导
                if viewStore.showReadingGuide {
                    ReadingGuideView {
                        viewStore.send(.updateShowReadingGuide(false))
                        viewStore.send(.okButtonTapped)
                        Request.tbaRequest(event: .readingGuideAgreen)
                    } skip: {
                        viewStore.send(.updateShowReadingGuide(false))
                        Request.tbaRequest(event: .readingGuideDisagreen)
                    }.onAppear{
                        Request.tbaRequest(event: .readingGuide)
                        GADUtil.share.load(.enter)
                    }
                }
            }.onAppear {
                viewStore.send(.showAD)
                Request.tbaRequest(event: .track)
                Request.tbaRequest(event: .homeAD)
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
    
    struct GuideView: View {
        let action: ()->Void
        var body: some View {
            ZStack{
                Color.black.opacity(0.9).ignoresSafeArea()
                VStack(spacing: 30){
                    HStack{Spacer()}
                    Spacer()
                    VStack(spacing: 0){
                        Image("tracker_guide")
                        Text(LocalizedStringKey("Record blood pressure status")).foregroundStyle(.white).font(.system(size: 17))
                    }
                    Button {
                        action()
                    } label: {
                        HStack(spacing: 7){
                            Spacer()
                            Image("guide_add")
                            Text("Add").foregroundStyle(.white).font(.system(size: 16.0)).padding(.vertical, 15)
                            Spacer()
                        }
                    }.background(.linearGradient(colors: [Color("#FFB985"), Color("#F89042")], startPoint: .leading, endPoint: .trailing)).cornerRadius(26).padding(.horizontal, 70)
                    Spacer()
                }
            }.onAppear {
                Request.tbaRequest(event: .guide)
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
    
    struct ReadingGuideView: View {
        let ok: ()->Void
        let skip: ()->Void
        @State var time: Int = 5
        let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
        var body: some View {
            ZStack{
                Color.black.opacity(0.7).ignoresSafeArea()
                VStack{
                    HStack{Spacer()}.frame(height: 1)
                    Spacer()
                    VStack(spacing: 18){
                        Image("reading_guide")
                        Text("Try to learn more about blood pressure health!").lineLimit(nil).multilineTextAlignment(.center).foregroundStyle(Color("#53545C")).font(.system(size: 16))
                        VStack(spacing: 12){
                            Button{
                                ok()
                            } label: {
                                HStack{
                                    Spacer()
                                    Text("ok").padding(.vertical,15).foregroundStyle(.white)
                                    Spacer()
                                }
                            }.background(.linearGradient(colors: [Color("#42C3D6"), Color("#5AE9FF")], startPoint: .leading, endPoint: .trailing)).cornerRadius(26).padding(.horizontal, 30)
                            Button {
                                if time == 0 {
                                    skip()
                                }
                            } label: {
                                if time > 0 {
                                    Text("Skip(\(time)s)").foregroundStyle(Color("#B4B3B3"))
                                } else {
                                    Text("Skip").foregroundStyle(Color("#42C3D6"))
                                }
                            }
                        }.font(.system(size: 16))
                    }.padding(.all, 20).background(Color("#F3F8FB")).cornerRadius(16).padding(.horizontal, 20)
                    Spacer()
                }
            }.onReceive(timer) { _ in
                if self.time > 0 {
                    self.time -= 1
                }
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
