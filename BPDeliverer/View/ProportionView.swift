//
//  ProportionView.swift
//  BPDeliverer
//
//  Created by yangjian on 2023/12/8.
//

import Foundation
import SwiftUI
import ComposableArchitecture

enum Filter: CaseIterable {
    case day, week, month
    var numberDay: Int {
        switch self {
        case .day:
            return 7
        case .week:
            return 14
        case .month:
            return 30
        }
    }
}

struct ProportionReducer: Reducer {
    struct State: Equatable {
        @UserDefault("measures", defaultValue: [])
        var measures: [Measurement]
        var filter = Filter.day
        let filters = Filter.allCases
        let descriptions = Measurement.Status.allCases
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

extension ProportionReducer.State {
    
    var filterMeasure: [Measurement] {
        measures.filter {
            $0.date <= Date().exactlyDay && $0.date > Date().exactlyDay.addingTimeInterval( -Double(filter.numberDay) * .day)
        }
    }
    
    var progress: [Double] {
        Measurement.Status.allCases.map { status in
            if filterMeasure.isEmpty {
                return 0.0
            }
            return Double(filterMeasure.filter({$0.status == status}).count) / Double(filterMeasure.count)
        }
    }
    
    var normalProgress: Double {
        if filterMeasure.isEmpty {
            return 0.0
        }
        return  Double(filterMeasure.filter({$0.status == .normal}).count) / Double(filterMeasure.count)
    }
    
    var normalDesc: String {
        "is the proportion of normal blood pressure values"
    }
}

struct ProportionView: View {
    let store: StoreOf<ProportionReducer>
    var body: some View {
        WithViewStore(store, observe: {$0}) { viewStore in
            ScrollView{
                VStack(spacing: 35){
                    VStack(spacing: 16){
                        NavigationBarView(backAction: {viewStore.send(.dismiss)}, title: "BP Proportion")
                        FilterButtonView(item: viewStore.filter) { item in
                            viewStore.send(.filterDidSelected(item))
                        }
                    }
                    VStack(spacing: 28){
                        ZStack{
                            CircleView(progress: viewStore.progress, colors: Measurement.Status.colors, lineWidth: 62).frame(width: 244, height: 244)
                            Text(verbatim: "\(Int(viewStore.normalProgress * 100))%").foregroundStyle(.black).font(.system(size: 12.0))
                        }
                        HStack{
                            Text(verbatim: "\(Int(viewStore.normalProgress * 100))% ")
                            Text(LocalizedStringKey(viewStore.normalDesc))
                        }.multilineTextAlignment(.center).foregroundColor(.black).font(.system(size: 16)).padding(.horizontal, 70)
                    }
                    DescriptionView(store: store).padding(.top, 20)
                    Spacer()
                }
            }.onAppear(perform: {
                GADUtil.share.load(.back)
            })
        }.background(Color("#F3F8FB").ignoresSafeArea())
    }
    
    struct DescriptionView: View {
        let store: StoreOf<ProportionReducer>
        var body: some View {
            WithViewStore(store, observe: {$0}) { viewStore in
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 25), GridItem(.flexible(), spacing: 25)], spacing: 16) {
                    ForEach(viewStore.descriptions.indices, id: \.self) { index in
                        HStack(spacing: 6.5){
                            Color(uiColor: Measurement.Status.colors[index]).frame(width: 13, height: 13).cornerRadius(6.5)
                            Text(LocalizedStringKey(viewStore.descriptions[index].title)).foregroundStyle(.black).font(.system(size: 14))
                            Spacer()
                        }
                    }
                }
            }.padding(.horizontal, 28)
        }
    }
}

struct NavigationBarView: View {
    let backAction: ()->Void
    let title: String
    var body: some View {
        ZStack{
            HStack{
                Spacer()
                Text(LocalizedStringKey(title)).foregroundStyle(.black).font(.system(size: 18))
                Spacer()
            }
            HStack{
                Spacer()
                Button(action: backAction) {
                    Image("charts_close").padding(.all, 20)
                }
            }
        }
    }
}

struct FilterButtonView: View {
    let item: Filter
    let didSelectedFilter: (Filter)->Void
    var body: some View {
        HStack{
            HStack(spacing: 20){
                ForEach(Filter.allCases, id: \.self) { item in
                    Button {
                        didSelectedFilter(item)
                    } label: {
                        VStack{
                            if item == self.item {
                                HStack(spacing: 0){
                                    Text("\(item.numberDay) ")
                                    Text(LocalizedStringKey("Days"))
                                }.padding(.all, 8).background(Color("#5AE9FF")).foregroundStyle(Color.white)
                            } else {
                                HStack(spacing: 0){
                                    Text("\(item.numberDay) ")
                                    Text(LocalizedStringKey("Days"))
                                }
                                .padding(.all, 8).foregroundStyle(Color("#BBCDD9"))
                            }
                        }
                    }
                    .font(.system(size: 18)).cornerRadius(20)
                }
            }.padding(.all, 8).shadow(28)
        }
        .padding(.vertical, 16).padding(.horizontal, 42)
    }
}
