//
//  GuideView.swift
//  BPDeliverer
//
//  Created by Super on 2024/2/23.
//

import Foundation
import SwiftUI
import Combine
import ComposableArchitecture

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

struct AllowUserView: View {
    let action: ()->Void
    var body: some View {
        ZStack{
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack{
                HStack{Spacer()}
                Spacer()
                VStack(spacing: 20){
                    Text(LocalizedStringKey("Disclaimer")).font(.system(size: 20, weight: .semibold)).foregroundStyle(Color("#242C44"))
                    Text(LocalizedStringKey("Disclaimer_desc")).font(.system(size: 16)).foregroundStyle(Color("#242C44")).lineLimit(nil).truncationMode(.tail).padding(.horizontal, 30)
                    Button(action: action, label: {
                        Text(LocalizedStringKey("OK")).font(.system(size: 15)).foregroundStyle(.white).padding(.vertical, 15).padding(.horizontal, 100)
                    }).background(Color("#42C3D6")).cornerRadius(26)
                }.padding(.vertical, 28).background(.white).cornerRadius(10).padding(.horizontal, 35)
                Spacer()
            }
        }
    }
}

struct MeasureGuideView: View {
    let action: ()->Void
    let skip: ()->Void
    var body: some View {
        ZStack{
            Color.black.opacity(0.9).ignoresSafeArea()
            if CacheUtil.shared.getMeasureGuide() == .b{
                contentView1(action: action, skip: skip)
            } else {
                contentView2(action: action, skip: skip)
            }
        }.onAppear {
            Request.tbaRequest(event: .guide)
        }
    }
    
    struct contentView1: View {
        let action: ()->Void
        let skip: ()->Void
        @State var time: Int = 5
        let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
        var color: Color {
            time > 0 ? Color("#BBCDD9") : Color.white
        }
        var title: String {
            time > 0 ? "Skip \(time)s" : "Skip"
        }
        var body: some View {
            VStack(spacing: 30){
                HStack{
                    Spacer()
                    Button(action: {
                        if time == 0 {
                            skip()
                        }
                    }, label: {
                        Text(title).padding(.horizontal, 16).padding(.vertical, 6).background(RoundedRectangle(cornerRadius: 15).stroke(color)).font(.system(size: 13))
                    }).foregroundColor(color).padding(.trailing, 12).padding(.top, 6)
                }
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
            }.onReceive(timer) { _ in
                if self.time > 0 {
                    self.time -= 1
                }
            }
        }
    }

    struct contentView2: View {
        let action: ()->Void
        let skip: ()->Void
        @State var time: Int = 5
        let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
        var color: Color {
            time > 0 ? Color("#BBCDD9") : Color("#194D54")
        }
        var title: String {
            time > 0 ? "Skip \(time)s" : "Skip"
        }
        var body: some View {
            VStack{
                HStack{
                    Spacer()
                    Button(action: {
                        if time == 0 {
                            skip()
                        }
                    }, label: {
                        Text(title).padding(.horizontal, 16).padding(.vertical, 6).background(RoundedRectangle(cornerRadius: 15).stroke(color)).font(.system(size: 13))
                    }).foregroundColor(color).padding(.trailing, 12).padding(.top, 6)
                }
                Spacer()
                VStack(spacing: 33){
                    Image("measure_guide")
                    Text("Please add at least one record to unlock statistics").lineLimit(nil).multilineTextAlignment(.center).padding(.top, 15).font(.system(size: 16)).foregroundColor(.black).padding(.horizontal, 60)
                    Button {
                        action()
                    } label: {
                        HStack{
                            Spacer()
                            Image("guide_add")
                            Text("Add")
                            Spacer()
                        }.foregroundColor(.white)
                    }.background(Image("guide_button_bg"))
                }
                Spacer()
            }.background(.white).onReceive(timer) { _ in
                if self.time > 0 {
                    self.time -= 1
                }
            }
        }
    }
}

struct BPProportionGuideView: View {
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
                    Image("guide_charts")
                    Text("Try to observe your blood pressure data statistics").lineLimit(nil).multilineTextAlignment(.center).foregroundStyle(Color("#53545C")).font(.system(size: 16))
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
