//
//  HeartView.swift
//  BPDeliverer
//
//  Created by yangjian on 2023/12/8.
//

import Foundation
import SwiftUI
import Combine
import ComposableArchitecture

struct HeartReducer: Reducer {
    struct State: Equatable {
        var filter: Filter = .day
        @UserDefault("measures", defaultValue: [])
        var measures: [Measurement]
    }
    enum Action: Equatable {
        case dismiss
        case filterDidSelected(Filter)
        
        case showBackAD
    }
    var body: some Reducer<State, Action> {
        Reduce{ state, action in
            if case let .filterDidSelected(filter) = action {
                state.filter = filter
            }
            if case .showBackAD = action {
                Request.tbaRequest(event: .backAD)
                let publisher = Future<Action, Never> { promise in
                    GADUtil.share.load(.back)
                    GADUtil.share.show(.back) { _ in
                        promise(.success(.dismiss))
                    }
                }
                return .publisher {
                    publisher
                }
            }
            return .none
        }
    }
}

extension HeartReducer.State {
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
                if partialResult.last?.day != d.day {
                    array.append(d)
                }
                return array
            }
        }
    }
    
    var average: [Int] {
        dates.map { date in
            let totalDayAverage = filterMeasure.filter { measure in
                return measure.date.exactlyDay == date.exactlyDay
            }.map { measure in
                measure.pulse
            }.reduce(0, +)
            let count = filterMeasure.filter { measure in
                return measure.date.exactlyDay == date.exactlyDay
            }.count
            return Int(Double(totalDayAverage) / Double(count))
        }
    }
    
    var averageValue: Int {
        if dates.count == 0 {
            return 0
        }
        return Int(Double(average.reduce(0, +)) / Double(dates.count))
    }
    
    var numberUnit: [Int] {
        Array(0...5).map { index in
            index * 30
        }
    }
    
    var unitString: [String] {
        numberUnit.map {
            "\($0)"
        }.reversed()
    }
}

struct HearView: View {
    let store: StoreOf<HeartReducer>
    var body: some View {
        WithViewStore(store, observe: {$0}) { viewStore in
            ScrollView{
                VStack(spacing: 35){
                    VStack(spacing: 16){
                        NavigationBarView(backAction: {viewStore.send(.showBackAD)}, title: "Heart Rate")
                        FilterButtonView(item: viewStore.filter) { item in
                            viewStore.send(.filterDidSelected(item))
                        }
                    }
                    AverageView(store: store)
                    ChartsView(store: store)
                    Spacer()
                }
            }.onAppear(perform: {
                GADUtil.share.load(.back)
            })
        }.background(Color("#F3F8FB").ignoresSafeArea())
    }
    
    struct AverageView: View {
        let store: StoreOf<HeartReducer>
        var body: some View {
            WithViewStore(store, observe: {$0}) { viewStore in
                VStack(spacing: 9){
                    Text(LocalizedStringKey("Your Average HR")).font(.system(size: 20)).foregroundStyle(Color("#BBCDD9"))
                    VStack{
                        Text(verbatim: "\(viewStore.averageValue)").font(.system(size: 42)).foregroundStyle(.black)
                        Text("BPM").foregroundStyle(Color("#BBCDD9"))
                    }.frame(width: 201, height: 115).shadow
                }
            }
        }
    }
    
    struct ChartsView: View {
        let store: StoreOf<HeartReducer>
        var body: some View {
            WithViewStore(store, observe: {$0}) { viewStore in
                ZStack{
                    HStack(spacing: 15){
                        UnitView(source: viewStore.unitString)
                        DottedLineView(source: Array(0...5))
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
        let store: StoreOf<HeartReducer>
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
                                            let da = Double(viewStore.average[index])
                                            let average = Double(da) >= 150.0 ? 150.0 : da
                                            let top = (150.0 - average) / 150.0 * (proxy.size.height - 16.0)
                                            let height = Double(da) / 150.0 * (proxy.size.height - 16.0)
                                            Text("\(Int(da))").frame(height: 16).padding(.top, top)
                                            HStack{
                                                Spacer()
                                                Color("#48CCE0").frame(width: 7.0, height: height).cornerRadius(3.5)
                                                Spacer()
                                            }
                                        }
                                    }.padding(.bottom, 8)
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
