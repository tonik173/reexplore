//
//  BaseOperation.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 01.07.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import Foundation

class BaseOperation: Operation
{
    private var running: Bool = false
    private var done: Bool = false
    private var suspended: Bool = false
    private static var rid: UInt = 0

    // ------------------------------------------------------------------------------------------------------
    // MARK: - Initialization -
    // ------------------------------------------------------------------------------------------------------
    
    override init()
    {
        super.init()
        
        self.queuePriority = .normal
        self.qualityOfService = .userInteractive
    }
    
    // ------------------------------------------------------------------------------------------------------
    // MARK: - To be overridden -
    // ------------------------------------------------------------------------------------------------------

    open func execute()
    {
    }

    // ------------------------------------------------------------------------------------------------------
    // MARK: - Services -
    // ------------------------------------------------------------------------------------------------------
    
    func suspend() -> Bool
    {
        var didSuspend = false
        if self.isReady {
            self.willChangeValue(forKey: "isReady")
            self.suspended = true
            self.didChangeValue(forKey: "isReady")
            didSuspend = true
        }
        return didSuspend;
    }
    
    func resume() -> Bool
    {
        let canResume = !self.isCancelled && !self.isFinished && !self.isReady && !self.isExecuting
        var didResume = false
        if canResume {
            self.willChangeValue(forKey: "isReady")
            self.suspended = false
            self.didChangeValue(forKey:"isReady")
            didResume = true
        }
        return didResume
    }
    
    func finish()
    {
        self.willChangeValue(forKey:"isExecuting")
        self.running = false
        self.didChangeValue(forKey:"isExecuting")
    
        self.willChangeValue(forKey:"isFinished")
        self.done = true
        self.didChangeValue(forKey:"isFinished")
    }
    
    func nextRequestId() -> UInt
    {
        BaseOperation.rid += 1
        return BaseOperation.rid
    }

    // ------------------------------------------------------------------------------------------------------
    // MARK: - Operation contract for async -
    // ------------------------------------------------------------------------------------------------------

    public func asynchronous() -> Bool
    {
        return true
    }
    
    override var isFinished: Bool
    {
        return self.done
    }
    
    override var isExecuting: Bool
    {
        return self.running;
    }
    
    override var isReady: Bool
    {
        let superIsReady = super.isReady
        return !self.suspended && superIsReady
    }
    
    override func start()
    {
        self.willChangeValue(forKey:"isExecuting")
        self.running = true
        self.didChangeValue(forKey:"isExecuting")
        self.execute()
    }
    
    // ------------------------------------------------------------------------------------------------------
    // MARK: - End -
    // ------------------------------------------------------------------------------------------------------
}
