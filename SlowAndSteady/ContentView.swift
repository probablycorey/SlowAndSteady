//
//  ContentView.swift
//  SlowAndSteady
//
//  Created by Corey Johnson on 7/1/21.
//

import SwiftUI

struct ContentView: View {
    @State var recorder = ScreenRecorder()

    var body: some View {
        VStack {
            Text("Record the screen")
                .font(.title)
                .padding()
                .foregroundColor(.green)
            Button("Toggle") {
                if (recorder.isRecording()) {
                    recorder.stop()
                    print("done")                    
                } else {
                    recorder.start()
                }
            }
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
