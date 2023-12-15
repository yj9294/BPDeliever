//
//  BPTrendsView.swift
//  BPDeliverer
//
//  Created by yangjian on 2023/12/8.
//

import Foundation
import SwiftUI
import ComposableArchitecture

struct BPTrendsReducer: Reducer {
    struct State: Equatable {
        var filter: Filter = .day
        @UserDefault("measures", defaultValue: [])
        var measures: [Measurement]
    }
    enum Action: Equatable {
        case dismiss
        case filterDidSelected(Filter)
    }
    var body: some Reducer<State, Action> {
        Reduce{ state, action in
            if case let .filterDidSelected(filter) = action {
                state.filter = filter
            }
            return .none
        }
    }
}

extension BPTrendsReducer.State {
    var filterMeasure: [Measurement] {
        measures.filter {
            $0.date <= Date().exactlyDay && $0.date > Date().exactlyDay.addingTimeInterval( -Double(filter.numberDay) * .day)
        }
    }
    
    var dates: [Date] {
        filterMeasure.map { measure in
            measure.date
        }.reduce([]) { partialResult, d in
            if partialResult.isEmpty {
                return [d]
            } else {
                var array = partialResult
                if partialResult.last?.exactlyDay != d.exactlyDay {
                    array.append(d)
                }
                return array
            }
        }
    }
    
    var systolic: [Int] {
        dates.map { date in
            filterMeasure.filter { measure in
                return measure.date.exactlyDay == date.exactlyDay
            }.max { m1, m2 in
                return m1.systolic < m2.systolic
            }?.systolic ?? 250
        }
    }
    
    var diastolic: [Int] {
        dates.map { date in
            filterMeasure.filter { measure in
                return measure.date.exactlyDay == date.exactlyDay
            }.min { m1, m2 in
                return m1.diastolic < m2.diastolic
            }?.diastolic ?? 30
        }
    }
    
    var averageSy: Int {
        if systolic.isEmpty {
            return 0
        }
        return systolic.reduce(0, +) / systolic.count
    }
    
    var averageDi: Int {
        if diastolic.isEmpty {
            return 0
        }
        return  diastolic.reduce(0, +) / diastolic.count
    }
    
    var numberUnit: [Int] {
        Array(1...8).map { index in
            index * 30
        }
    }
    
    var unitString: [String] {
        numberUnit.map {
            "\($0)"
        }.reversed()
    }
}

struct BPTrendsView: View {
    let store: StoreOf<BPTrendsReducer>
    var body: some View {
        WithViewStore(store, observe: {$0}) { viewStore in
            ScrollView{
                VStack(spacing: 35){
                    VStack(spacing: 16){
                        NavigationBarView(backAction: {viewStore.send(.dismiss)}, title: "BP Trends")
                        FilterButtonView(item: viewStore.filter) { item in
                            viewStore.send(.filterDidSelected(item))
                        }
                    }
                    AverageView(store: store)
                    ChartsView(store: store)
                    Spacer()
                }
            }
        }.background(Color("#F3F8FB").ignoresSafeArea())
    }
    
    struct AverageView: View {
        let store: StoreOf<BPTrendsReducer>
        var body: some View {
            WithViewStore(store, observe: {$0}) { viewStore in
                VStack(spacing: 16){
                    VStack(spacing: 9){
                        Text(LocalizedStringKey("Your Average BP")).font(.system(size: 20)).foregroundStyle(Color("#BBCDD9"))
                        VStack{
                            Text(verbatim: "\(viewStore.averageSy)-\(viewStore.averageDi)").font(.system(size: 42)).foregroundStyle(.black)
                            Text("mmHg")
                        }.frame(width: 201, height: 115).shadow
                    }
                    Text(LocalizedStringKey("The normal range 120-80 mmHg")).font(.system(size: 12.0)).foregroundStyle(Color("#BBCDD9"))
                }
            }
        }
    }
    
    struct ChartsView: View {
        let store: StoreOf<BPTrendsReducer>
        var body: some View {
            WithViewStore(store, observe: {$0}) { viewStore in
                ZStack{
                    HStack(spacing: 15){
                        UnitView(source: viewStore.unitString)
                        DottedLineView(source: Array(1...8))
                    }.padding(.bottom, 36).padding(.top, 8)
                    DataView(store: store)
                }
            }.padding(.horizontal, 16)
        }
    }
    
    struct UnitView: View {
        let source: [String]
        var body: some View {
            VStack(spacing: 15){
                ForEach(source, id: \.self) { str in
                    Text(str).font(.system(size: 12)).foregroundStyle(Color("#A6BFC8")).frame(width: 30, height: 17)
                }
            }
        }
    }
    
    struct DottedLineView: View {
        let source: [Int]
        var body: some View {
            GeometryReader{ proxy in
                VStack(spacing: 15){
                    ForEach(source, id: \.self) { _ in
                        Path{ path in
                            path.move(to: CGPoint(x: 0, y: 7))
                            path.addLine(to: CGPoint(x: proxy.size.width, y: 7))
                        }.stroke(style: .init(lineWidth: 1.0, dash: [3])).foregroundColor(Color("#E6E9EB"))
                    }
                }
            }
        }
    }
    
    struct DataView: View {
        let store: StoreOf<BPTrendsReducer>
        var body: some View {
            WithViewStore(store, observe: {$0}) { viewStore in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHGrid(rows: [GridItem(.flexible())]) {
                        ForEach(viewStore.dates.indices, id: \.self) { index in
                            VStack(spacing: 0){
                                HStack{
                                    Spacer()
                                    GeometryReader{ proxy in
                                        VStack(spacing: 0){
                                            let systolic = Double(viewStore.systolic[index]) >= 240 ? 240.0 : Double(viewStore.systolic[index])
                                            let top = (240.0 - systolic) / 210.0 * (proxy.size.height - 32.0)
                                            let height = (Double(viewStore.systolic[index]) - Double(viewStore.diastolic[index])) / 210.0 * (proxy.size.height - 32.0)
                                            Text(verbatim: "\(viewStore.systolic[index])").frame(height: 16).padding(.top, top)
                                            Color("#48CCE0").frame(width: 7.0, height: height).cornerRadius(3.5)
                                            Text(verbatim: "\(viewStore.diastolic[index])").frame(height: 16)
                                        }
                                    }
                                    Spacer()
                                }
                                Text(viewStore.dates[index].unitDay).frame(height: 14).padding(.vertical, 11)
                            }.font(.system(size: 10)).foregroundColor(Color("#A6BFC8"))
                        }
                    }
                }.padding(.leading, 45)
            }
        }
    }
}
