(in-package :o2)

(defclass state ()
  ((name :initform (error "Name must be set") ;; TODO drop
         :initarg :name)
   (application :initform (error "Application must be set")
                :initarg :application)
   (renderer :initform (error "Renderer must be set")
             :initarg :renderer)
   (running :initform nil
            :accessor running?)
   (actor :initform nil
          :accessor actor)
   (objects :initform (list)
            :reader objects)
   (camera :initform (cons 0 0)
           :accessor camera)

   ;; FIXME: is this really the best place for it?
   (score :initform 0
          :accessor score)))

(defgeneric init (state))
(defgeneric process-input (state direction keysym))
(defgeneric update (state &key &allow-other-keys))
(defgeneric render (state))
(defgeneric cleanup (state))
(defgeneric add-object (state object))

(defmethod init ((state state)))

(defmethod update ((state state) &key dt &allow-other-keys)
  (with-slots (running objects) state
    (when running
      (dolist (object objects)
        (update object)))))

(defmethod add-object ((state state) (object game-object))
  (with-slots (objects) state
    (push object objects)
    (setf objects (sort objects #'< :key #'(lambda (it) (render-priority it))))
    object))

(defmethod remove-object ((state state) (object game-object))
  (with-slots (objects) state
    (setf objects
          (sort (remove object objects) #'< :key #'(lambda (it) (render-priority it))))))

