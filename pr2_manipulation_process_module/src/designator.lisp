;;; Copyright (c) 2010, Lorenz Moesenlechner <moesenle@in.tum.de>
;;; All rights reserved.
;;; 
;;; Redistribution and use in source and binary forms, with or without
;;; modification, are permitted provided that the following conditions are met:
;;; 
;;;     * Redistributions of source code must retain the above copyright
;;;       notice, this list of conditions and the following disclaimer.
;;;     * Redistributions in binary form must reproduce the above copyright
;;;       notice, this list of conditions and the following disclaimer in the
;;;       documentation and/or other materials provided with the distribution.
;;;     * Neither the name of Willow Garage, Inc. nor the names of its
;;;       contributors may be used to endorse or promote products derived from
;;;       this software without specific prior written permission.
;;; 
;;; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
;;; AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
;;; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
;;; ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
;;; LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
;;; CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
;;; SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
;;; INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
;;; CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
;;; ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
;;; POSSIBILITY OF SUCH DAMAGE.

(in-package :pr2-manipulation-process-module)

(defun make-message (type-str slots)
  (apply #'roslisp::make-message-fn type-str slots))

(defun missing (list1 list2 &key (test #'eql))
  (loop for item in list2
        when (not (find item list1 :test test))
          collect item))

(defun arm-for-pose (pose)
  (let ((frame (tf:frame-id pose)))
    (cond ((string= frame "/r_wrist_roll_link") :right)
          ((string= frame "/l_wrist_roll_link") :left))))

(def-fact-group pr2-manipulation-designators (action-desig)

  (<- (flatten ?list-of-lists ?list)
    (lisp-fun alexandria:flatten ?list-of-lists ?list))

  (<- (missing ?list-current ?list-full ?list-missing)
    (lisp-fun missing ?list-current ?list-full ?list-missing))

  (<- (min-handles ?object-desig ?min-handles)
    (current-designator ?object-desig ?current-object)
    (or (desig-prop ?current-object (min-handles ?min-handles))
        (equal ?min-handles 1)))

  (<- (ros-message ?type ?slots ?msg)
    (lisp-fun make-message ?type ?slots ?msg))

  (<- (obstacles ?desig ?obstacles)
    (findall ?o (desig-prop ?desig (obstacle ?o))
             ?obstacles))

  (<- (absolute-handle ?object-desig ?handle ?absolute-handle)
    (current-designator ?object-desig ?current-object)
    (handles ?current-object ?handles)
    (member ?handle ?handles)
    (lisp-fun absolute-handle ?current-object ?handle ?absolute-handle))

  (<- (handles ?desig ?handles)
    (findall ?h (desig-prop ?desig (handle ?h))
             ?handles))

  (<- (gripper-arms-in-desig ?desig ?arms)
    (current-designator ?desig ?current-desig)
    (gripped-obj-desig? ?current-desig)
    (desig-prop ?current-desig (at ?obj-loc))
    (desig-prop ?obj-loc (gripper ?_))
    (findall ?g (desig-prop ?obj-loc (gripper ?g))
             ?arms))

  (<- (gripper-arms-in-belief ?desig ?arms)
    (current-designator ?desig ?current-desig)
    (findall ?g (object-in-hand ?current-desig ?g)
             ?arms))

  (<- (holding-arms ?desig ?arms)
    (current-designator ?desig ?current-desig)
    (gripper-arms-in-belief ?current-desig ?arms))

  (<- (handled-obj-desig? ?designator)
    (obj-desig? ?designator)
    (desig-prop ?designator (handle ?_)))

  (<- (gripped-obj-desig? ?designator)
    (obj-desig? ?designator)
    (desig-prop ?designator (at ?obj-loc))
    (loc-desig? ?obj-loc)
    (desig-prop ?obj-loc (in gripper)))

  (<- (action-desig ?desig (container-opened ?current-obj ?grasp-assignments
                                             ?angle))
    (trajectory-desig? ?desig)
    (desig-prop ?desig (to open))
    (desig-prop ?desig (obj ?obj))
    (current-designator ?obj ?current-obj)
    (handles ?current-obj ?handles)
    (desig-prop ?desig (angle ?angle))
    (available-arms ?current-obj ?available-arms)
    (optimal-handle-grasp ?current-obj ?available-arms ?grasp-assignments))

  (<- (action-desig ?desig (debug))
    (trajectory-desig? ?desig)
    (desig-prop ?desig (to debug)))
  
  (<- (action-desig ?desig (container-closed ?handle :right))
    (trajectory-desig? ?desig)
    (desig-prop ?desig (to close))
    (desig-prop ?desig (handle ?handle)))

  ;; On the PR2 we don't need an open pose
  (<- (action-desig ?desig (noop ?desig))
    (trajectory-desig? ?desig)
    (desig-prop ?desig (pose open)))

  (<- (action-desig ?desig (park ?obj ?arms))
    (trajectory-desig? ?desig)
    (desig-prop ?desig (to park))
    (desig-prop ?desig (obj ?obj))
    (current-designator ?obj ?current-obj)
    (holding-arms ?current-obj ?arms))

  (<- (action-desig ?desig (park nil nil))
    (trajectory-desig? ?desig)
    (desig-prop ?desig (to park)))

  (<- (action-desig ?desig (lift ?arms ?distance))
    (trajectory-desig? ?desig)
    (desig-prop ?desig (to lift))
    (desig-prop ?desig (obj ?obj))
    (current-designator ?obj ?current-obj)
    (holding-arms ?current-obj ?arms)
    (-> (desig-prop ?desig (distance ?distance))
        (true)
        (== ?distance 0.10)))

  (<- (action-desig ?desig (park ?obj ?arms ?obstacles))
    (trajectory-desig? ?desig)
    (desig-prop ?desig (to carry))
    (desig-prop ?desig (obj ?obj))
    (current-designator ?obj ?current-obj)
    (holding-arms ?current-obj ?arms)
    (obstacles ?desig ?obstacles))

  ;; rule added by Georg:
  ;; right now, it is intended to be limited to grasping of
  ;; handled objects, i.e. the ones produced by the gazebo
  ;; perception process module.
  ;; later, however, it could be used as the general rule for
  ;; all grasping because the predicate 'best-grasp' can be
  ;; used as a hook for grasp planning or any other manipulation
  ;; reasoning process that chooses the correct arm/grasp setup
  (<- (available-arms ?obj ?available-arms)
    (available-arms ?obj ?available-arms (:left :right)))

  (<- (available-arms ?obj ?available-arms ?possible-arms)
    (or (setof ?arms-object (object-in-hand ?_ ?arms-object) ?arms-used-list)
        (equal ?arms-used-list ()))
    (flatten ?arms-used-list ?arms-used)
    (missing ?arms-used ?possible-arms ?available-arms))
  
  (<- (arm-for-pose ?pose ?arm)
    (lisp-fun arm-for-pose ?pose ?arm))
  
  (<- (action-desig ?desig (grasp ?current-obj ?grasp-assignments ?obstacles))
    (trajectory-desig? ?desig)
    (desig-prop ?desig (to grasp))
    (desig-prop ?desig (obj ?obj))
    (current-designator ?obj ?current-obj)
    (obstacles ?desig ?obstacles)
    (handles ?current-obj ?handles)
    (available-arms ?current-obj ?available-arms)
    (optimal-handle-grasp ?current-obj ?available-arms ?grasp-assignments))

  (<- (action-desig ?desig (grasp ?current-obj ?grasp-assignments ?obstacles))
    (trajectory-desig? ?desig)
    (desig-prop ?desig (to grasp))
    (desig-prop ?desig (obj ?obj))
    (newest-effective-designator ?obj ?current-obj)
    (obstacles ?desig ?obstacles)
    (available-arms ?current-obj ?available-arms)
    (optimal-grasp ?current-obj ?available-arms ?grasp-assignments))

  (<- (optimal-handle-grasp ?object-desig ?available-arms ?grasp-assignments)
    (current-designator ?object-desig ?current-object)
    (handles ?current-object ?handles)
    (min-handles ?current-object ?min-handles)
    (setof (?handle . ?absolute-handle) (absolute-handle ?current-object
                                                         ?handle
                                                         ?absolute-handle)
           ?absolute-handles)
    (lisp-fun optimal-arm-handle-assignment
              ?current-object
              ?available-arms
              ?absolute-handles
              ?min-handles
              ?grasp-assignments)
    (length ?grasp-assignments ?assignment-count)
    (> ?assignment-count 0))

  (<- (optimal-grasp ?object-desig ?available-arms ?grasp-assignments)
    (current-designator ?object-desig ?current-desig)
    (desig-prop ?current-desig (at ?loc))
    (desig-prop ?loc (pose ?pose))
    (lisp-fun optimal-arm-pose-assignment
              ?current-object
              ?available-arms
              ?pose
              ?grasp-assignments)
    (length ?grasp-assignments ?assignment-count)
    (> ?assignment-count 0))
  
  (<- (grasped-object-handle ?obj ?handle)
    (handles ?obj ?handles)
    (member ?handles ?handle)
    (object-in-hand ?handle))
  
  (<- (grasped-object-part ?obj ?part)
    (or (grasped-object-handle ?obj ?part)
        (equal ?obj ?part)))

  (<- (action-desig ?desig (put-down ?current-obj ?loc ?grasp-assignments ?obstacles))
    (trajectory-desig? ?desig)
    (desig-prop ?desig (to put-down))
    (desig-prop ?desig (obj ?obj))
    (current-designator ?obj ?current-obj)
    (obstacles ?desig ?obstacles)
    (desig-prop ?desig (at ?loc))
    (desig-prop ?current-obj (desig-props:at ?objloc))
    (desig-prop ?objloc (desig-props:in desig-props:gripper))
    (setof ?posearm (and (desig-prop ?objloc (desig-props:pose ?objpose))
                         (arm-for-pose ?objpose ?arm)
                         (member ?arm (:left :right))
                         (equal ?posearm (?arm . ?objpose)))
           ?poses)
    (lisp-fun cons-to-grasp-assignments ?poses ?grasp-assignments))
  
  (<- (action-desig ?desig (pull ?current-obj ?arms
                                 ?direction ?distance
                                 ?obstacles))
    (trajectory-desig? ?desig)
    (desig-prop ?desig (to pull))
    (desig-prop ?desig (obj ?obj))
    (desig-prop ?desig (distance ?distance))
    (desig-prop ?desig (direction ?direction))
    (current-designator ?obj ?current-obj)
    (grasped-object-part ?obj ?grasped)
    (holding-arms ?current-obj ?arms)
    (obstacles ?desig ?obstacles))

  (<- (action-desig ?desig (push ?current-obj ?arms
                                 ?direction ?distance
                                 ?obstacles))
    (trajectory-desig? ?desig)
    (desig-prop ?desig (to push))
    (desig-prop ?desig (obj ?obj))
    (desig-prop ?desig (distance ?distance))
    (desig-prop ?desig (direction ?direction))
    (current-designator ?obj ?current-obj)
    (holding-arms ?current-obj ?arms)
    (obstacles ?desig ?obstacles))

  (<- (action-desig ?desig (put-down ?current-obj ?loc ?arms ?obstacles))
    (trajectory-desig? ?desig)
    (desig-prop ?desig (to put-down))
    (desig-prop ?desig (obj ?obj))
    (current-designator ?obj ?current-obj)
    (holding-arms ?current-obj ?arms)
    (desig-prop ?desig (at ?loc))
    (obstacles ?desig ?obstacles)))

(def-fact-group manipulation-process-module (matching-process-module available-process-module)

  (<- (matching-process-module ?designator pr2-manipulation-process-module)
    (and (trajectory-desig? ?designator)
         (or (desig-prop ?designator (to grasp))
             (desig-prop ?designator (to put-down))
             (desig-prop ?designator (to open))
             (desig-prop ?designator (to close))
             (desig-prop ?designator (to park))
             (desig-prop ?designator (pose open))        
             (desig-prop ?designator (to lift))
             (desig-prop ?designator (to carry))
             (desig-prop ?designator (to pull))
             (desig-prop ?designator (to push))
             (desig-prop ?designator (to debug)))))

  (<- (available-process-module pr2-manipulation-process-module)
    (not (projection-running ?_))))
