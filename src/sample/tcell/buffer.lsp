;;; ̤����

;;; ���������ѥХåե�
;;; reader �� writer �����줾�����1����å�Ʊ����ư���Ƥ�����פʤ��Ȥ��ݾ�

(defconstant *buffer-init-size* 4096)
(defconstant *init-buffer-unit-length* 1)

;; (defclass buffer ()
;;   ((size :accessor buf-size :type fixnum :initform *buffer-init-size*)
;;    (body :accessor buf-body :type (array unsigned-byte))
;;    (wp :accessor buf-wp :type fixnum :initform 0)
;;    (rp :accessor buf-rp :type fixnum :initform 0)
;;    (lock :accessor buf-lock :type mp:process-lock :initform (mp:make-process-lock))
;;    ���Ǥʤ��ʤä����Ȥ�����
;;    (gate :accessor buf-gate :type gate :initform (mp:make-gate nil)))
;;   )

;; (defmethod initialize-instance ((buf buffer))
;;   (setf (buf-body buf)
;;     (make-array (buf-size buf) :element-type 'unsigned-byte :adjustable t)))


(defconstant *buffer-unit-size* 4096)
(defconstant *init-buffer-unit-length* 1)

(defclass buffer-unit ()
  ((size :accessor buf-u-size :type fixnum :initform *buffer-unit-size*)
   (body :accessor buf-u-body :type (array unsigned-byte))
   ;; �������Ƭ����ΰ������ö�ɤ�ǡ�����³�����ɤ�Ȥ������Ȥϲ�ǽ
   ;; ��˥åȤΤ����������ɤޤ줿��Ƭ��ʬ�˽񤭹��ळ�Ȥ��Բ�ǽ�ʥХåե����ĥ�����
   (written-to :accessor buf-u-written :type fixnum :initform 0)
                                        ; �ǡ������񤭹��ޤ줿�ϰϤ� 0���(1- <written-to>)
   (read-to :accessor buf-u-read :type fixnum :initform 0)
                                        ; �ǡ������ɤ���ϰϤ� 0���(1- <read-to>)
   (lock :accessor buf-u-lock :type mp:process-lock :initform (mp:make-process-lock)))
  )

(defclass buffer ()
  ((body :accessor buf-body :type list) ; body�ν۴ĥꥹ��
   (read-pointer :accessor buf-p-rd)     ; �����ɤ߹���Ȥ���
   (write-pointer :accessor buf-p-wr)    ; �Ǹ�˽񤭹�����Ȥ���
   ;; buffer-unit�ꥹ�Ȥι�¤���Ѳ�������Ȥ����ꥹ�Ȥ�é��Ȥ��˳���
   (lock :accessor buf-lock :type mp:process-lock :initform (mp:make-proces-lock))
   ;; ���Ǥʤ��ʤä����Ȥ�����
   (gate :accessor buf-gate :type gate :initform (mp:make-gate nil)))
  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defmethod initialize-instance ((bu buffer-unit))
  (setf (buf-u-body bu)
    (make-array (buf-u-size bu) :element-type 'unsigned-byte)))


(defmethod initialize-instance ((buf buffer))
  (let ((len *init-buffer-unit-length*))
    (setf (buf-body buf) (make-list len :initial-element (make-instance 'buffer-unit)))
    (rplacd (last (buf-body buf)) (buf-body buf)))
  (setf (buf-p-rd buf) (buf-body buf))
  (setf (buf-p-wr buf) (buf-body buf)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defmethod readable-buffer-unit-p ((bu buffer-unit))
  (mp:with-process-lock ((buf-u-lock bu))
    (< (buf-u-read bu) (buf-u-written bu))))

(defmethod writable-buffer-unit-p ((bu buffer-unit))
  (mp:with-process-lock ((buf-u-lock bu))
    (< (buf-u-written bu) (buf-u-size bu))))

;;;

;;; size �� �ɤ߽񤭤������Υ�����
;;; �º��ɤ߽񤭤��������� & unit�κǸ�ޤ��ɤ߽񤭤�����(t/nil)  ���֤��ͤȤ���

;; stream�����ɤ��buffer-unit �˽񤭹���
(defmethod read-into-buffer-unit ((bu buffer-unit) (s input-stream) size)
  (mp:with-process-lock ((buf-u-lock bu))
    (setf (buf-u-read bu) 0)
    (read-sequence (buf-u-body bu) :end size)
    (setf (buf-u-written bu) size)))

;;; buffer-unit�����ɤ�� stream��ή��
(defmethod write-from-buffer-unit ((bu buffer-unit) (s output-stream) size)
  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defmethod read-into-buffer ((buf buffer) (s input-stream) size)
  (declare (fixnum size))
  (let ((usize *buffer-unit-size*))
    (loop
        with rem = size
        while (> rem 0)
        as wp = (mp:with-process-lock ((buf-lock buf))
                  (unless (writable-buffer-unit-p (cdr (buf-p-wr buf)))
                    (expand-buffer buf))
                  (cdr (buf-p-wr buf)))
        do
          (read-into-buffer-unit (car wp) s rd-size)
          (setf (buf-p-wr buf) wp)
          (mp:open-gate (buf-gate buf)))))

(defmethod write-from-buffer ((buf buffer) (s output-stream) size)
  (declare (fixnum size))
  (loop
      with rem = size
      while (> rem 0)
      as rd-size = (loop
                     (unless (readable-buffer-unit-p (buf-p-rd buf))
                       (close-gate (buf-gate buf))
                       (mp:process-wait "Waiting for the buffer being non-empty."
                                        #'gate-open-p (buf-gate buf)))
                     (write-from-buffer-unit (car (buf-p-rd buf)) rem))
      do (decf rem rd-size)
         (mp:with-process-lock ((buf-lock buf))
           (setf (buf-p-rd buf) (cdr (buf-p-rd buf))))))
       