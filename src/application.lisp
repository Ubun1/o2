(in-package :o2)

(defparameter +delay+ (/ 1000.0 30.0) "FPS")

(defvar *application* nil "Instance of the current application.")

(defun res ()
  (merge-pathnames #p"res/" +root+))

(defun res/gfx (file-name)
  (merge-pathnames file-name (merge-pathnames #p"gfx/" (res))))

(defun res/snd (file-name)
  (merge-pathnames file-name (merge-pathnames #p"snd/" (res))))

(defun res/fonts (file-name)
  (merge-pathnames file-name (merge-pathnames #p"fonts/" (res))))

(defclass application ()
  ((states :initform (make-hash-table)
           :reader states)
   (current-state :initform nil
                  :reader current-state)
   (renderer :initform nil)
   (running? :initform nil)))

(defun make-application ()
  (setf *application* (make-instance 'application)))

(defun current-app-state ()
  (current-state *application*))

(defun deregister-state (app state-name)
  (with-slots (states) app
    (when (gethash state-name states)
      (setf (gethash state-name states) nil))))

(defun register-state (app state-class state-name)
  (with-slots ((states states)
               (ren renderer)
               current-state) app
    (if (gethash state-name states)
        (error "State ~a already registered" state-name))
    (let ((state (make-instance state-class
                                :application app
                                :name state-name
                                :renderer ren)))
      (unless current-state (setf current-state state))
      (setf (gethash state-name states) state))))

(defun set-state (app state-name &key no-reinit)
  (with-slots ((states states)
               current-state) app
    (let ((state (gethash state-name states)))
      (unless state (error "State ~a is not registered." state-name))
      (setf current-state state)
      (unless no-reinit (init state)))))

(defun get-state (app state-name)
  (or (gethash state-name (states app) nil)
      (error "No state with name ~S" state-name)))

(defmacro continuable (&body body)
  "A macro to disable livesupport when in SLIME"
  #+slynk
  `(livesupport:continuable ,@body)
  #-slynk
  `(progn ,@body))

(defmethod start ((app application))
  (sdl2-image:init '(:png))
  (sdl2-ttf:init)
  (sdl2:with-init (:video)
    (sdl2:with-window (win :title "o2"
                           :w 1024
                           :h 768)
      (sdl2:with-renderer (ren win
                          :flags '(:accelerated :presentvsync))
        (let* ((renderer (make-instance 'renderer :renderer ren))
               current-frame)

          (set-current-renderer renderer)
          (setf (slot-value app 'renderer) renderer)

          (add-sprite :background (res/gfx "background-placeholder.png"))
          (add-sprite :player (res/gfx "player-placeholder.png"))
          (add-sprite :player-sitting (res/gfx "player-sitting-placeholder.png"))
          (add-sprite :bad-guy (res/gfx "bad-guy-placeholder.png"))
          (add-sprite :9x19 (res/gfx "9x19.png"))

          (add-font :ubuntu (res/fonts "Ubuntu-R.ttf") :font-size 16)

          (register-state app 'ingame-state :ingame)
          (set-state app :ingame)

          (with-slots ((state current-state)) app
            (continuable
              (sdl2:with-event-loop (:method :poll)
                (:keydown (:keysym keysym)
                          (process-input state :keydown keysym))
                (:keyup (:keysym keysym)
                        (process-input state :keyup keysym))
                (:idle ()
                       (setf current-frame (sdl2:get-ticks))
                       ;; TODO move out to :before and :after render

                       #+slynk
                       (livesupport:update-repl-link)

                       (sdl2:render-clear ren)
                       (update state)
                       (render state)
                       (sdl2:render-present ren)
                       (let ((current-speed (- (sdl2:get-ticks)
                                               current-frame)))
                         (when (< current-speed +delay+)
                           (sdl2:delay (round (- +delay+ current-speed))))))
                (:quit ()
                       (sdl2-ttf:close-font (get-font :ubuntu))
                       (setf *application* nil)

                       (sdl2-image:quit)
                       (sdl2-ttf:quit)
                       t)))))))))
