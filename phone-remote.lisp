(in-package #:phone-remote)

;;; Keyboard Input
(defun init-vks ()
  (let ((ret (make-hash-table :size 36)))
    (loop for char from (char-code #\0) to (char-code #\9)
	  for vk from #x30 to #x39
	  do (setf (gethash (code-char char) ret) vk))
    (loop for char from (char-code #\A) to (char-code #\Z)
	  for vk from #x41 to #x5A
	  do (setf (gethash (code-char char) ret) vk))
    ret))

(defparameter *vks* (init-vks))
(defun get-vk (char)
  (gethash char *vks*))

(defun send-keydown (virtual-keycode)
  (cffi:with-foreign-object (inputs 'win32:input 1)
    (cffi:with-foreign-slots ((win32:type win32:input) (cffi:mem-aref inputs 'win32:input 0)  win32:input)
      (cffi:with-foreign-slots ((mi win32:ki hi) win32:input win32:input_input-union)
	(cffi:with-foreign-slots ((win32:vk scan flags time extra-info) win32:ki  win32:keybdinput)
	  (setf win32:type 1
		win32:vk virtual-keycode))))
    (win32:send-input 1 inputs (cffi:foreign-type-size 'win32:input))))

(defun send-keyup (virtual-keycode)
  (cffi:with-foreign-object (inputs 'win32:input 1)
    (cffi:with-foreign-slots ((win32:type win32:input) (cffi:mem-aref inputs 'win32:input 0) win32:input)
      (cffi:with-foreign-slots ((mi win32:ki hi) win32:input win32:input_input-union)
	(cffi:with-foreign-slots ((win32:vk scan win32:flags time extra-info) win32:ki win32:keybdinput)
	  (setf win32:type 1
		win32:vk virtual-keycode
		win32:flags 2))))
    (win32:send-input 1 inputs (cffi:foreign-type-size 'win32:input))))

;;; Config
(defun read-config (filespec)
  "Read the first line in filespec as the host address."
  (with-open-file (f filespec)
    (read-line f)))

;;; Webserver
(defun start-server ()
  (hunchentoot:start (make-instance 'hunchentoot:easy-acceptor
				    :document-root "./webpage/"
				    :port 0)))

;;; QR code
(defun create-qr-code (address port)
  (cl-qrencode:encode-png (format nil "~A:~A" address port)))

;;; Websockets
(defclass ws-client (hunchensocket:websocket-client) ())
(defclass ws-server (hunchensocket:websocket-resource)
  ((player :initarg :player :initform (error "Assign me a player number!") :reader player))
  (:default-initargs :client-class 'ws-client))

(defmethod hunchensocket:client-connected ((server ws-server) client)
  (format t "~&Client connected to server ~A." (player server))
  (force-output))
(defmethod hunchensocket:client-disconnected ((server ws-server) client)
  (format t "~&Client disconnected from server ~A." (player server))
  (force-output))
(defmethod hunchensocket:text-message-received ((server ws-server) client message)
  (format t "~&Server ~A recieved: | ~A |" (player server) message)
  (force-output))  


(defparameter *ws-servers* (list (make-instance 'ws-server :player "/1")
				 (make-instance 'ws-server :player "/2")))

(defun find-room (request)
  (find (hunchentoot:script-name request) *ws-servers* :test #'string= :key #'player))

(defun start-ws-server ()
  (pushnew 'find-room hunchensocket:*websocket-dispatch-table*)
  (hunchentoot:start (make-instance 'hunchensocket:websocket-acceptor :port 0)))

;;; Main

