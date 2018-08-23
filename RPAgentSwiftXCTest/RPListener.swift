//
//  Listener.swift
//  com.oxagile.automation.RPAgentSwiftXCTest
//
//  Created by Sergey Komarov on 5/12/17.
//  Copyright © 2017 Oxagile. All rights reserved.
//

import Foundation
import XCTest

public class RPListener: NSObject, XCTestObservation {
  
  private var reportingService: ReportingService!
  private let queue = DispatchQueue(label: "com.report_portal.reporting", qos: .utility)
  var bundleProperties: [String: Any]!
  
  public override init() {
    super.init()
    
    
    XCTestObservationCenter.shared.addTestObserver(self)
  }
  
  private func readConfiguration(from testBundle: Bundle) -> AgentConfiguration {
    guard
      let bundlePath = testBundle.path(forResource: "Info", ofType: "plist"),
      let bundleProperties = NSDictionary(contentsOfFile: bundlePath) as? [String: Any],
      let shouldReport = bundleProperties["PushTestDataToReportPortal"] as? Bool,
      let portalPath = bundleProperties["ReportPortalURL"] as? String,
      let portalURL = URL(string: portalPath),
      let projectName = bundleProperties["ReportPortalProjectName"] as? String,
      let token = bundleProperties["ReportPortalToken"] as? String,
      let launchName = bundleProperties["ReportPortalLaunchName"] as? String else
    {
      fatalError("Configure properties for report portal in the Info.plist")
    }
    var tags: [String] = []
    if let tagString = bundleProperties["ReportPortalTags"] as? String {
      tags = tagString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).components(separatedBy: ",")
    }
    
    return AgentConfiguration(
      reportPortalURL: portalURL,
      projectName: projectName,
      launchName: launchName,
      shouldSendReport: shouldReport,
      portalToken: token,
      tags: tags
    )
  }
  
  public func testBundleWillStart(_ testBundle: Bundle) {
    let configuration = readConfiguration(from: testBundle)
    
    guard configuration.shouldSendReport else {
      print("Set 'YES' for 'PushTestDataToReportPortal' property in Info.plist if you want to put data to report portal")
      return
    }
    reportingService = ReportingService(configuration: configuration)
    queue.async {
      do {
        try self.reportingService.startLaunch()
      } catch let error {
        print(error)
      }
    }
  }
  
  public func testSuiteWillStart(_ testSuite: XCTestSuite) {
    if !testSuite.name.contains("Selected tests"), !testSuite.name.contains(".xctest") {
      queue.async {
        do {
          try self.reportingService.startTestSuite(testSuite)
        } catch let error {
          print(error)
        }
      }
    }
  }
  
  public func testSuite(_ testSuite: XCTestSuite, didFailWithDescription description: String, inFile filePath: String?, atLine lineNumber: Int) {
    
  }
  
  public func testCaseWillStart(_ testCase: XCTestCase) {
    queue.async {
      do {
        try self.reportingService.startTest(testCase)
      } catch let error {
        print(error)
      }
    }
  }
  
  public func testCase(_ testCase: XCTestCase, didFailWithDescription description: String, inFile filePath: String?, atLine lineNumber: Int) {
    queue.async {
      do {
        try self.reportingService.reportError(message: "Test '\(String(describing: testCase.name)))' failed on line \(lineNumber), \(description)")
      } catch let error {
        print(error)
      }
    }
  }
  
  public func testCaseDidFinish(_ testCase: XCTestCase) {
    queue.async {
      do {
        try self.reportingService.finishTest(testCase)
      } catch let error {
        print(error)
      }
    }
  }
  
  public func testSuiteDidFinish(_ testSuite: XCTestSuite) {
    if !testSuite.name.contains("Selected tests"), !testSuite.name.contains(".xctest") {
      queue.async {
        do {
          try self.reportingService.finishTestSuite()
        } catch let error {
          print(error)
        }
      }
    }
  }
  
  public func testBundleDidFinish(_ testBundle: Bundle) {
    queue.sync() {
      do {
        try self.reportingService.finishLaunch()
      } catch let error {
        print(error)
      }
    }
  }
}
