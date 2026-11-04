import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private var pencil: PencilInteractionBridge?

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    // The storyboard's Flutter view controller is in place once the scene
    // has connected.
    DispatchQueue.main.async { [weak self] in
      guard let self,
        let flutter = self.window?.rootViewController as? FlutterViewController
      else { return }
      self.pencil = PencilInteractionBridge(attachingTo: flutter)
    }
  }
}

/// Sends Apple Pencil double-taps (and Pencil Pro squeezes) to Dart over the
/// `mnote/stylus` channel, along with the action the person chose for them in
/// Settings › Apple Pencil, so the app does what they expect.
final class PencilInteractionBridge: NSObject, UIPencilInteractionDelegate {
  private let channel: FlutterMethodChannel

  init(attachingTo flutter: FlutterViewController) {
    channel = FlutterMethodChannel(
      name: "mnote/stylus",
      binaryMessenger: flutter.binaryMessenger
    )
    super.init()
    let interaction = UIPencilInteraction()
    interaction.delegate = self
    flutter.view.addInteraction(interaction)
  }

  private static func name(of action: UIPencilPreferredAction) -> String {
    switch action {
    case .switchEraser: return "switchEraser"
    case .switchPrevious: return "switchPrevious"
    default: return "ignore"
    }
  }

  // iOS 12.1–17.4.
  func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
    channel.invokeMethod(
      "tap", arguments: Self.name(of: UIPencilInteraction.preferredTapAction))
  }

  @available(iOS 17.5, *)
  func pencilInteraction(
    _ interaction: UIPencilInteraction,
    didReceiveTap tap: UIPencilInteraction.Tap
  ) {
    channel.invokeMethod(
      "tap", arguments: Self.name(of: UIPencilInteraction.preferredTapAction))
  }

  @available(iOS 17.5, *)
  func pencilInteraction(
    _ interaction: UIPencilInteraction,
    didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze
  ) {
    guard squeeze.phase == .ended else { return }
    channel.invokeMethod(
      "squeeze",
      arguments: Self.name(of: UIPencilInteraction.preferredSqueezeAction))
  }
}
