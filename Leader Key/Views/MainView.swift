//
//  MainView.swift
//  Leader Key
//
//  Created by Mikkel Malmberg on 19/04/2024.
//

import SwiftUI

struct MainView: View {
  @EnvironmentObject var userState: UserState

  var body: some View {
    Text(userState.currentGroup?.key ?? userState.display ?? "●")
      .fontDesign(.rounded)
      .fontWeight(.semibold)
      .font(.system(size: 28, weight: .semibold, design: .rounded))
      .frame(width: 200, height: 200, alignment: .center)
      .background(
        VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
      )
      .clipShape(RoundedRectangle(cornerRadius: 25.0, style: .continuous))
  }
}

struct MainView_Previews: PreviewProvider {
  static var previews: some View {
    MainView().environmentObject(UserState(userConfig: UserConfig()))
  }
}
