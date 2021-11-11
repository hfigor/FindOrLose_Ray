/// Copyright (c) 2019 Razeware LLC
/// 
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
/// 
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
/// 
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
/// 
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import UIKit
import Combine

class GameViewController: UIViewController {
  // MARK: - Variables
  var subscriptions: Set<AnyCancellable> = []
  

  var gameState: GameState = .stop {
    didSet {
      switch gameState {
        case .play:
          playGame()
        case .stop:
          stopGame()
      }
    }
  }

  var gameImages: [UIImage] = []
/*  var gameTimer: Timer?
 Timer is another Foundation type that has had Combine functionality added to it. You're going to migrate across to the Combine version to see the differences.
*/
  var gameTimer: AnyCancellable?
  /*
   You're now storing a subscription to the timer, rather than the timer itself. This can be represented with AnyCancellable in Combine.
   From xcode docs via cmd+click
   /// A type-erasing cancellable object that executes a provided closure when canceled.
   ///
   /// Subscriber implementations can use this type to provide a “cancellation token” that makes it possible for a caller to cancel a publisher, but not to use the ``Subscription`` object to request items.
   ///
   /// An ``AnyCancellable`` instance automatically calls ``Cancellable/cancel()`` when deinitialized.
   
   /// Cancel the activity.
   ///
   /// When implementing ``Cancellable`` in support of a custom publisher, implement `cancel()` to request that your publisher stop calling its downstream subscribers. Combine doesn't require that the publisher stop immediately, but the `cancel()` call should take effect quickly. Canceling should also eliminate any strong references it currently holds.
   ///
   /// After you receive one call to `cancel()`, subsequent calls shouldn't do anything. Additionally, your implementation must be thread-safe, and it shouldn't block the caller.
   ///
   /// > Tip: Keep in mind that your `cancel()` may execute concurrently with another call to `cancel()` --- including the scenario where an ``AnyCancellable`` is deallocating --- or to ``Subscription/request(_:)``.
   */
  var gameLevel = 0
  var gameScore = 0

  // MARK: - Outlets

  @IBOutlet weak var gameStateButton: UIButton!

  @IBOutlet weak var gameScoreLabel: UILabel!

  @IBOutlet var gameImageView: [UIImageView]!

  @IBOutlet var gameImageButton: [UIButton]!

  @IBOutlet var gameImageLoader: [UIActivityIndicatorView]!

  // MARK: - View Controller Life Cycle

  override func viewDidLoad() {
    precondition(!UnsplashAPI.accessToken.isEmpty, "Please provide a valid Unsplash access token!")

    title = "Find or Lose"
    gameScoreLabel.text = "Score: \(gameScore)"
  }

  // MARK: - Game Actions

  @IBAction func playOrStopAction(sender: UIButton) {
    gameState = gameState == .play ? .stop : .play
  }

  @IBAction func imageButtonAction(sender: UIButton) {
    let selectedImages = gameImages.filter { $0 == gameImages[sender.tag] }
    
    if selectedImages.count == 1 {
      playGame()
    } else {
      gameState = .stop
    }
  }

  // MARK: - Game Functions

  func playGame() {
    //gameTimer?.invalidate()
    gameTimer?.cancel()

    gameStateButton.setTitle("Stop", for: .normal)

    gameLevel += 1
    title = "Level: \(gameLevel)"

    gameScoreLabel.text = "Score: \(gameScore)"
    gameScore += 200

    resetImages()
    startLoaders()
    
    let firstImage = UnsplashAPI.randomImage()
      .flatMap{ randomImageResponse in
        ImageDownloader.download(url: randomImageResponse.urls.regular)
      }
    
    let secondImage = UnsplashAPI.randomImage()
      .flatMap { randomImageResponse in
        ImageDownloader.download(url: randomImageResponse.urls.regular)
      }
    
    /*
     At this point, you have downloaded two random images. Now it’s time to, pardon the pun, combine them. You’ll use zip to do this.
     */
    firstImage.zip(secondImage)
      .receive(on: DispatchQueue.main)
      .sink(receiveCompletion: { [unowned self] completion in
        
        switch completion {
        case .finished: break
        case .failure(let error):
          print("Error \(error)")
          self.gameState = .stop
        }
      }, receiveValue: { [unowned self] first, second in
        self.gameImages = [first, second, second, second].shuffled()
        self.gameScoreLabel.text = "Score: \(self.gameScore)"
        
        // TODO: Handle game score
        /*
         don't know how I would know to make these timer calls since type-ahead does not match this at all
        Here's the breakdown:
        You use the new API for vending publishers from Timer. The publisher will repeatedly send the current date at the given interval, on the given run loop.
        The publisher is a special type of publisher that needs to be explicitly told to start or stop. The .autoconnect operator takes care of this by connecting or disconnecting as soon as subscriptions start or are canceled.
        The publisher can't ever fail, so you don't need to deal with a completion. In this case, sink makes a subscriber that just processes values using the closure you supply.
        */
        self.gameTimer = Timer.publish(every: 0.1, on: RunLoop.main, in: .common)
          .autoconnect()
          .sink { [unowned self] _ in
            self.gameScoreLabel.text = "Score: \(self.gameScore)"
            self.gameScore -= 10
            if self.gameScore <= 0 {
              self.gameScore = 0
              //timer.invalidate()
              self.gameTimer?.cancel()
            }
            
          }
        
        self.stopLoaders()
        self.setImages()
      })
      .store(in: &subscriptions)
//
//    UnsplashAPI.randomImage { [unowned self] randomImageResponse in
//      guard let randomImageResponse = randomImageResponse else {
//        DispatchQueue.main.async {
//          self.gameState = .stop
//        }
//
//        return
//      }
//
//      ImageDownloader.download(url: randomImageResponse.urls.regular) { [unowned self] image in
//        guard let image = image else { return }
//
//        self.gameImages.append(image)
//
//        UnsplashAPI.randomImage { [unowned self] randomImageResponse in
//          guard let randomImageResponse = randomImageResponse else {
//            DispatchQueue.main.async {
//              self.gameState = .stop
//            }
//
//            return
//          }
//
//          ImageDownloader.download(url: randomImageResponse.urls.regular) { [unowned self] image in
//            guard let image = image else { return }
//
//            self.gameImages.append(contentsOf: [image, image, image])
//            self.gameImages.shuffle()
//
//            DispatchQueue.main.async {
//              self.gameScoreLabel.text = "Score: \(self.gameScore)"
//
//              self.gameTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [unowned self] timer in
//                DispatchQueue.main.async {
//                  self.gameScoreLabel.text = "Score: \(self.gameScore)"
//                }
//                self.gameScore -= 10
//
//                if self.gameScore <= 0 {
//                  self.gameScore = 0
//
//                  timer.invalidate()
//                }
//              }
//
//              self.stopLoaders()
//              self.setImages()
//            }
//          }
//        }
//      }
//    }
  }

  func stopGame() {
    //gameTimer?.invalidate()
    // Here, you iterate over all subscriptions and cancel them.
    subscriptions.forEach { $0.cancel()}
    
    gameTimer?.cancel()

    gameStateButton.setTitle("Play", for: .normal)

    title = "Find or Lose"

    gameLevel = 0

    gameScore = 0
    gameScoreLabel.text = "Score: \(gameScore)"

    stopLoaders()
    resetImages()
  }

  // MARK: - UI Functions

  func setImages() {
    if gameImages.count == 4 {
      for (index, gameImage) in gameImages.enumerated() {
        gameImageView[index].image = gameImage
      }
    }
  }

  func resetImages() {
    // Here, you assign an empty array that will remove all the references to the unused subscriptions.
    subscriptions = []
    gameImages = []

    gameImageView.forEach { $0.image = nil }
  }

  func startLoaders() {
    gameImageLoader.forEach { $0.startAnimating() }
  }

  func stopLoaders() {
    gameImageLoader.forEach { $0.stopAnimating() }
  }
}
