//
//  ARCubeView.swift
//  ARRubiks
//
//  Created by Nicholas Grana on 6/10/17.
//  Copyright © 2017 Nicholas Grana. All rights reserved.
//

import ARKit

class ARCubeView: ARSCNView, UIGestureRecognizerDelegate {
    
    var cube: ARCubeNode!
    var selectedContainer: SCNNode?
    var selectedSide: Side?
    
    var beginPoint:SCNVector3?
    var firstHitNode:SCNNode?
    var currentMoveDirection:MoveDirection?
    var oldMoveDirection:MoveDirection?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        setup()
    }
    
    public override init(frame: CGRect, options: [String : Any]? = nil) {
        super.init(frame: frame, options: options)
        setup()
    }
    
    
    func setup() {
        func setupCube() {
            cube = ARCubeNode()
            
//            cube.position = SCNVector3(0, -0.1, -0.3)//as the init position isn't the center,so calculat the Side error. remove this to fix side calculat result
            cube.scale = SCNVector3(0.05, 0.05, 0.05)
            
            scene.rootNode.addChildNode(cube)
        }
        func setupGestures() {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(swipe(_:)))
            pan.delegate = self
            addGestureRecognizer(pan)
        }
        
        setupCube()
        setupGestures()
    }
    
    func side(from: SCNHitTestResult?) -> Side? {
        guard let from = from else {
            return nil
        }
        
        let pos = from.worldCoordinates
        let top = SCNVector3(0, 5, 0).distance(to: pos)
        let bottom = SCNVector3(0, -5, 0).distance(to: pos)
        let left = SCNVector3(-5, 0, 0).distance(to: pos)
        let right = SCNVector3(5, 0, 0).distance(to: pos)
        let back = SCNVector3(0, 0, -5).distance(to: pos)
        let front = SCNVector3(0, 0, 5).distance(to: pos)
        
        let all = [top, bottom, left, right, back, front]
        
        if top.isSmallest(from: all) {
            return .top
        } else if bottom.isSmallest(from: all) {
            return .bottom
        } else if left.isSmallest(from: all) {
            return .left
        } else if right.isSmallest(from: all) {
            return .right
        } else if back.isSmallest(from: all) {
            return .back
        } else if front.isSmallest(from: all) {
            return .front
        }
        
        return nil
    }
    
    @objc func swipe(_ gestureRecognize: UIPanGestureRecognizer) {
        if cube.animating {
            return
        }
        
        let point = gestureRecognize.location(in: self)
        let hitResults = hitTest(point, options: [SCNHitTestOption.boundingBoxOnly:true])
        
        if gestureRecognize.state == .began {
            beginPoint = hitResults.first?.worldCoordinates
            firstHitNode = hitResults.first?.node
        } else if gestureRecognize.state == .changed || gestureRecognize.state == .ended {
            if let changedPoint = hitResults.first?.worldCoordinates {
                if let directionAndDistance = beginPoint?.direction(to: changedPoint){
                    currentMoveDirection = directionAndDistance.direction
                    cube.offset = CGFloat(directionAndDistance.distance)
                }
            }
        }
        if selectedSide == nil {
            selectedSide = side(from: hitResults.first)
            print("selected side:%@", selectedSide as Any)
            if selectedSide == nil {
                return
            }
        }
        //在确定了方向和接触面后，如果selectedContainer为空，则addChildNode,只添加一次
        if gestureRecognize.state == .changed && selectedContainer == nil && currentMoveDirection != nil && selectedSide != nil && firstHitNode != nil {
            oldMoveDirection = currentMoveDirection
            selectedContainer = self.getContainerWith(parentNode:cube,hitNode:firstHitNode!,direction:currentMoveDirection!,selectedSide:selectedSide!)
            cube.addChildNode(selectedContainer!)
        }
        //当检测的移动方向发生改变时，需要重新设置selectedContainer
        if let oldDirection = oldMoveDirection {
            if oldDirection != currentMoveDirection{
                selectedContainer?.rotation = SCNVector4()//还原旋转方向
                for node in self.selectedContainer?.childNodes ?? [SCNNode]() {
                    self.cube.addChildNode(node)
                }
                self.selectedContainer?.removeFromParentNode()
                if currentMoveDirection != nil && selectedSide != nil && firstHitNode != nil {
                    oldMoveDirection = currentMoveDirection
                    selectedContainer = self.getContainerWith(parentNode: cube, hitNode: firstHitNode!, direction: currentMoveDirection!, selectedSide: selectedSide!)
                    cube.addChildNode(selectedContainer!)
                }
            }
        }
        //当selectedContainer不空时，实时修改旋转的角度
        if (gestureRecognize.state == .changed || gestureRecognize.state == .ended) && selectedContainer != nil {
            let rotation: SCNVector4? = SCNVector4.init(direction: currentMoveDirection!, selectedSide: selectedSide!, degrees: Float(cube.offset).offsetSwitchToDegrees())
            selectedContainer?.rotation = rotation!
        }
        
        if gestureRecognize.state == .ended {
            print("cube node nubmer:",cube.childNodes.count)
            if let container = selectedContainer {
                cube.doRotation(container: container, direction: currentMoveDirection!, selectedSide: selectedSide!,finished: {
                    for node in self.selectedContainer?.childNodes ?? [SCNNode]() {
                        node.transform = self.selectedContainer!.convertTransform(node.transform, to: self.cube)
                        self.cube.addChildNode(node)
                    }
                    self.selectedContainer?.removeFromParentNode()
                    print("after rotation ,cube node number:",self.cube.childNodes.count)
                    self.selectedContainer = nil
                    self.currentMoveDirection = nil;
                    self.oldMoveDirection = nil
                    self.selectedSide = nil
                    self.cube.offset = 0;
                    self.cube.animating = false
                })
            }
            
        }
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func getContainerWith(parentNode:SCNNode,hitNode:SCNNode,direction:MoveDirection,selectedSide:Side) -> SCNNode? {
        var selectedContainer:SCNNode?
        if direction == .xAxis {
            if selectedSide == .top || selectedSide == .bottom {//绕z轴旋转
                selectedContainer = Coordinate.zCol(parentNode, hitNode.position.z).container()
            } else {//绕y轴旋转
                selectedContainer = Coordinate.yRow(parentNode, hitNode.position.y).container()
            }
        } else if direction == .yAxis {
            if selectedSide == .front || selectedSide == .back { //绕x轴旋转
                selectedContainer = Coordinate.xCol(parentNode, hitNode.position.x).container()
            } else {//绕z轴旋转
                selectedContainer = Coordinate.zCol(parentNode, hitNode.position.z).container()
            }
        } else if direction == .zAxis {
            if selectedSide == .top || selectedSide == .bottom {//绕x轴旋转
                selectedContainer = Coordinate.xCol(parentNode, hitNode.position.x).container()
            } else {//绕y轴旋转
                selectedContainer = Coordinate.yRow(parentNode, hitNode.position.y).container()
            }
        }
        return selectedContainer
    }
    
}
