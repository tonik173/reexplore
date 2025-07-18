//
//  GameView.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 16.06.2020.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import MetalKit

class GameView: MTKView
{
    var inputController: InputController?
    var isSwipe = false
    var didAccelerate = false
    var controlsShown = false
    var showsMap = false
    weak var viewControllerDelegate: LocalViewControllerDelegate?
    
    fileprivate var locStart: CGPoint = .zero
    fileprivate let cornerRadius: CGFloat = 12
    fileprivate let animationDuration = 0.5
    
    @IBOutlet weak var acceleratorView: UIImageView!
    @IBOutlet weak var miniGameView: MiniGameView!
    @IBOutlet weak var thumbHorizontalLayoutConstraint: NSLayoutConstraint!
    @IBOutlet weak var thumbVerticalLayoutConstraint: NSLayoutConstraint!
    @IBOutlet weak var throttleLeadingLayoutConstraint: NSLayoutConstraint!
    @IBOutlet weak var throttleTrailingLayoutConstraints: NSLayoutConstraint!
    
    @IBOutlet weak var menuView: UIImageView!
    @IBOutlet weak var locationView: UIImageView!
    
    @IBOutlet weak var recordTrackView: UIImageView!
    @IBOutlet weak var recordTrackContainerView: UIView!
    @IBOutlet weak var closeRecordTrackContainerView: UIView!
    @IBOutlet var recordTrackContainerViewLengthConstraint: NSLayoutConstraint!   // if weak, it disappears when deactivated
    @IBOutlet weak var segmentBackBtn: UIView!
    @IBOutlet weak var segmentIndexLabel: UILabel!
    @IBOutlet weak var trackRecordBtn: UIView!
    @IBOutlet weak var trackFlagBtn: UIView!
    @IBOutlet weak var recordLabel: UILabel!
    @IBOutlet weak var recordImage: UIImageView!
    var isRecording: Bool = false
    var isRecordTrackContainerViewOpen: Bool = true
    var recordTrackContainerViewInitialWidth: CGFloat? = .none
    var recordImageInitalColor: UIColor!
    
    @IBOutlet weak var displayTrackIcon: UIImageView!
    @IBOutlet weak var displayTrackContainerView: UIView!
    @IBOutlet weak var closeDisplayTrackContainerView: UIView!
    @IBOutlet var displayTrackContainerViewLengthConstraint: NSLayoutConstraint! // if weak, it disappears when deactivated
    @IBOutlet weak var uploadBtn: UIView!
    @IBOutlet weak var uploadImage: UIImageView!
    @IBOutlet weak var uploadedTrackNameLabel: UILabel!
    var isDisplayTrackContainerViewOpen: Bool = true
    var hasUploadedTrack: Bool = false
    var displayTrackContainerViewInitialWidth: CGFloat? = .none
    
    @IBOutlet weak var resetView: UIView!
    @IBOutlet weak var resetBtn: UIButton!
    
    override func awakeFromNib()
    {
        super.awakeFromNib()
        
        self.uploadedTrackNameLabel.text = "uploadGpx".localized
        
        self.recordTrackContainerView.layer.cornerRadius = cornerRadius
        self.closeRecordTrackContainerView.layer.cornerRadius = cornerRadius
        self.recordTrackContainerViewLengthConstraint.isActive = false
        self.recordImageInitalColor = self.recordImage.tintColor
        
        NotificationCenter.default.addObserver(forName: Notifications.updateSegment, object: nil, queue: nil) { (notification) in
            if let segmentIndex = Notifications.payload(forUpdateSegmentNotification: notification) {
                self.segmentIndexLabel.text = segmentIndex
            }
        }
        
        self.displayTrackContainerView.layer.cornerRadius = cornerRadius
        self.closeDisplayTrackContainerView.layer.cornerRadius = cornerRadius
        self.displayTrackContainerViewLengthConstraint.isActive = false
        
        self.resetView.layer.cornerRadius = 3
        self.resetBtn.setTitle("reset".localized, for: .normal)
    }
    
    override func layoutSubviews()
    {
        super.layoutSubviews()
        
        if self.recordTrackContainerViewInitialWidth == .none {
            self.recordTrackContainerViewInitialWidth = self.recordTrackContainerView.frame.size.width
            self.closeTrackView(withDuration: 0)
        }
        
        if self.displayTrackContainerViewInitialWidth == .none {
            self.displayTrackContainerViewInitialWidth = self.displayTrackContainerView.frame.size.width
            self.closeLocationView(withDuration: 0)
        }
        
        switch Preferences.preferedControllerSide {
        case .left:
            throttleLeadingLayoutConstraint.priority = UILayoutPriority(1000)
            throttleTrailingLayoutConstraints.priority = UILayoutPriority(1)
        case .right:
            throttleLeadingLayoutConstraint.priority = UILayoutPriority(1)
            throttleTrailingLayoutConstraints.priority = UILayoutPriority(1000)
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        var didProcess = false
        if let location = touches.first?.location(in: self.acceleratorView) {
            if acceleratorView.bounds.contains(location) {
                if let location = touches.first?.location(in: self.acceleratorView) {
                    self.locStart = location
                }
                didProcess = true
                didAccelerate = true
                inputController?.processEvent(touches: touches, state: .began, event: event, in: acceleratorView)
            }
        }
        if let location = touches.first?.location(in: menuView) {
            if menuView.bounds.contains(location) {
                didProcess = true
                if let delegate = self.viewControllerDelegate {
                    delegate.didHitMenu()
                }
            }
        }
        if let location = touches.first?.location(in: locationView) {
            if locationView.bounds.contains(location) {
                didProcess = true
                if let delegate = self.viewControllerDelegate {
                    delegate.didHitLocation()                }
            }
        }
        if let location = touches.first?.location(in: displayTrackIcon) {
            if displayTrackIcon.bounds.contains(location) {
                didProcess = true
                if isDisplayTrackContainerViewOpen {
                    self.closeLocationView(withDuration: animationDuration)
                }
                else {
                    self.openLocationView()
                }
            }
        }
        if self.self.isDisplayTrackContainerViewOpen,
           let location = touches.first?.location(in: uploadBtn) {
            if uploadBtn.bounds.contains(location) {
                didProcess = true
                self.uploadTrack()
            }
        }
        if let location = touches.first?.location(in: recordTrackView) {
            if recordTrackView.bounds.contains(location) {
                didProcess = true
                if isRecordTrackContainerViewOpen {
                    self.closeTrackView(withDuration: animationDuration)
                }
                else {
                    self.openTrackView()
                }
            }
        }
        if self.self.isRecordTrackContainerViewOpen,
           let location = touches.first?.location(in: segmentBackBtn) {
            if segmentBackBtn.bounds.contains(location) {
                didProcess = true
                Log.gui("trackBack")
                if let vc = self.viewControllerDelegate as? ViewController {
                    vc.backToTrackSegmentStart()
                }
            }
        }
        if self.self.isRecordTrackContainerViewOpen,
           let location = touches.first?.location(in: trackRecordBtn) {
            // record track
            if trackRecordBtn.bounds.contains(location) {
                didProcess = true
                self.trackRecord()
            }
        }
        if self.self.isRecordTrackContainerViewOpen,
           let location = touches.first?.location(in: trackFlagBtn) {
            if trackFlagBtn.bounds.contains(location) {
                didProcess = true
                Log.gui("flagLocation")
                if let vc = self.viewControllerDelegate as? ViewController {
                    vc.startNewTrackSegment()
                }
            }
        }
        if let location = touches.first?.location(in: miniGameView) {
            if miniGameView.bounds.contains(location) {
                didProcess = true
                if let delegate = self.viewControllerDelegate {
                    if showsMap {
                        delegate.didHitRider()
                    }
                    else {
                        delegate.didHitMap()
                    }
                    showsMap = !showsMap
                }
            }
        }
        
        if !didProcess {
            if let location = touches.first?.location(in: self) {
                isSwipe = true
                swipe(location, state: .began)
            }
        }
        
        super.touchesBegan(touches, with: event)
    }
    
    var prevValueH: Float = 0
    var prevValueV: Float = 0
    fileprivate func swipe(_ location: CGPoint, state: InputState)
    {
        if let delegate = self.viewControllerDelegate {
            
            let h = Float(location.x/self.bounds.width)
            let v = 1 - Float(location.y/self.bounds.height)
            
            if state == .moved {
                
                let diffH = h - prevValueH
                let diffV = v - prevValueV
                
                Log.gui("swipe horizontally \(h)|\(diffH) and vertically \(v)|\(diffV)")
                
                if abs(diffV) > abs(diffH) {
                    delegate.didSwipeVertically(val: Float(diffV))
                }
                else {
                    self.inputController?.currentPitch = Float(diffH) * 100
                }
            }
            
            prevValueH = h
            prevValueV = v
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        if didAccelerate {
            inputController?.processEvent(touches: touches, state: .moved, event: event, in: self.acceleratorView)
            
            if let location = touches.first?.location(in: self.acceleratorView) {
                let y = (location.y - self.locStart.y) * 0.5
                let diffY = min(10, max(-50, y))
                
                let x = (location.x - self.locStart.x) * 0.25
                let diffX = min(10, max(-50, x))
                
                thumbVerticalLayoutConstraint.constant = diffY
                thumbHorizontalLayoutConstraint.constant = diffX
            }
        }
        else if isSwipe {
            if let location = touches.first?.location(in: self) {
                swipe(location, state: .moved)
            }
        }
        super.touchesMoved(touches, with: event)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        if didAccelerate || isSwipe {
            inputController?.processEvent(touches: touches, state: .ended, event: event, in: self.acceleratorView)
        }
        
        didAccelerate = false
        self.thumbHorizontalLayoutConstraint.constant = 0
        self.thumbVerticalLayoutConstraint.constant = 0
        
        isSwipe = false
        super.touchesEnded(touches, with: event)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        didAccelerate = false
        isSwipe = false
        super.touchesCancelled(touches, with: event)
    }
    
    // ------------------------------------------------------------------------------------------------------
    // MARK: - Track recording
    // ------------------------------------------------------------------------------------------------------

    fileprivate func openTrackView()
    {
        if let _ = self.viewControllerDelegate {
            UIView.animate(withDuration: self.animationDuration/4, delay: 0, options: .curveLinear) {
                self.recordTrackContainerView.alpha = 1
            } completion: { (done) in
                self.recordTrackContainerViewLengthConstraint.constant = self.recordTrackContainerViewInitialWidth!
                self.recordTrackContainerViewLengthConstraint.isActive = false
                UIView.animate(withDuration: self.animationDuration, delay: 0, options: .curveLinear) {
                    self.layoutIfNeeded()
                } completion: { (done) in
                    self.isRecordTrackContainerViewOpen = true
                }
            }
        }
    }
    
    fileprivate func closeTrackView(withDuration duration: TimeInterval)
    {
        self.isRecordTrackContainerViewOpen = false
        self.recordTrackContainerViewLengthConstraint.constant = 54
        self.recordTrackContainerViewLengthConstraint.isActive = true
        UIView.animate(withDuration: duration, delay: 0, options: .curveLinear) {
            self.layoutIfNeeded()
        } completion: { (done) in
            UIView.animate(withDuration: duration/4, delay: 0, options: .curveLinear) {
                self.recordTrackContainerView.alpha = 0
            }
        }
    }
    
    fileprivate func trackRecord()
    {
        if self.isRecording {
            Log.gui("save record track")
            self.recordImage.tintColor = self.recordImageInitalColor
            self.recordLabel.text = "Record"
            if let vc = self.viewControllerDelegate as? ViewController {
                if let xml = vc.stopRecordingTrack() {
                    vc.save(xml: xml, withSourceView: self.recordImage)
                }
            }
        }
        else {
            Log.gui("record track")
            self.recordImage.tintColor = UIColor.red
            self.recordLabel.text = "Stop\nrecording"
            if let vc = self.viewControllerDelegate as? ViewController {
                vc.startRecordingTrack()
            }
        }
        
        self.isRecording = !self.isRecording
    }
    
    // ------------------------------------------------------------------------------------------------------
    // MARK: - Track displaying
    // ------------------------------------------------------------------------------------------------------

    func didLoadTrack(withName name: String)
    {
        self.uploadedTrackNameLabel.text = name
        self.hasUploadedTrack = true
        self.uploadImage.image = UIImage(systemName: "mappin.slash")
    }
    
    fileprivate func uploadTrack()
    {
        if self.hasUploadedTrack {
            Log.gui("remove upload")
            self.uploadedTrackNameLabel.text = "uploadGpx".localized
            self.uploadImage.image = UIImage(systemName: "mappin.and.ellipse")
            self.hasUploadedTrack = false
            
            if let delegate = self.viewControllerDelegate {
                delegate.hideGpxTrack()
            }
        }
        else {
            Log.gui("upload")
            if let delegate = self.viewControllerDelegate {
                delegate.chooseGpxFile()
            }
        }
    }
    
    fileprivate func openLocationView()
    {
        if let _ = self.viewControllerDelegate {
            // tracking feature is available
            UIView.animate(withDuration: self.animationDuration/4, delay: 0, options: .curveLinear) {
                self.displayTrackContainerView.alpha = 1
            } completion: { (done) in
                self.displayTrackContainerViewLengthConstraint.constant = self.displayTrackContainerViewInitialWidth!
                self.displayTrackContainerViewLengthConstraint.isActive = false
                UIView.animate(withDuration: self.animationDuration, delay: 0, options: .curveLinear) {
                    self.layoutIfNeeded()
                } completion: { (done) in
                    self.isDisplayTrackContainerViewOpen = true
                }
            }
        }
    }
    
    fileprivate func closeLocationView(withDuration duration: TimeInterval)
    {
        self.isDisplayTrackContainerViewOpen = false
        self.displayTrackContainerViewLengthConstraint.constant = 54
        self.displayTrackContainerViewLengthConstraint.isActive = true
        UIView.animate(withDuration: duration, delay: 0, options: .curveLinear) {
            self.layoutIfNeeded()
        } completion: { (done) in
            UIView.animate(withDuration: duration/4, delay: 0, options: .curveLinear) {
                self.displayTrackContainerView.alpha = 0
            }
        }
    }
    
    // ------------------------------------------------------------------------------------------------------
    // MARK: - Elevation View
    // ------------------------------------------------------------------------------------------------------

    @IBAction func resetElevationView(_ sender: Any)
    {
        self.miniGameView.reset()
    }
    
}

// ------------------------------------------------------------------------------------------------------
// MARK: - MiniGameViewBase
// ------------------------------------------------------------------------------------------------------

class MiniGameView: MiniGameViewBase
{
    override var bounds: CGRect {
        didSet {
            resizeElevation(frame: self.bounds)
        }
    }
}
