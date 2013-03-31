;;; Copyright (c) 2008 Tasuku Hiraishi <hiraisi@kuis.kyoto-u.ac.jp>
;;; All rights reserved.

;;; Redistribution and use in source and binary forms, with or without
;;; modification, are permitted provided that the following conditions
;;; are met:
;;; 1. Redistributions of source code must retain the above copyright
;;;    notice, this list of conditions and the following disclaimer.
;;; 2. Redistributions in binary form must reproduce the above copyright
;;;    notice, this list of conditions and the following disclaimer in the
;;;    documentation and/or other materials provided with the distribution.

;;; THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND
;;; ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
;;; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
;;; ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR BE LIABLE
;;; FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
;;; DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
;;; OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
;;; HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
;;; LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
;;; OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
;;; SUCH DAMAGE.

;;; Definitions of define-ruleset and defrule/extendrule

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(provide "SCT-DEFRULE")
(eval-when (:compile-toplevel :load-toplevel :execute)
  (require "SC-DECL" "sc-decl.lsp"))

(scr:require "SC-MISC")
(scr:require "SC-FILE")

(in-package "SC-TRANSFORMER")

(defparameter *ruleset-arg* 'ruleset-instance)
(eval-when (:compile-toplevel :load-toplevel :execute)
  (defconstant *rule-class-package* (find-package "RULE"))
  (defconstant *base-ruleset-class-name* (intern "RULESET" *rule-class-package*)))

;; .rule �ե����뤬�֤��Ƥ���ǥ��쥯�ȥ�
(defvar *rule-path* (make-pathname :directory (directory+ scr:*sc-system-path* "rule/")))

;;; default-handler�����Ѵؿ�
(defun rule:return-no-match (x)
  (declare (ignore x))
  'rule::no-match)

(defun rule:throw-no-match (x)
  (declare (ignore x))
  (throw 'rule::no-match nil))

(defun rule:try-rule (rule-func &rest args)
  (catch 'rule::no-match
    (apply rule-func args))
  )

;; Ruleset �Υ١������饹
(defclass #.*base-ruleset-class-name* ()
  ((rule:entry :initform 'error-no-entry :type symbol) ; �ǽ�˸ƤӽФ���§̾
   (rule:default-handler :initform #'rule:return-no-match :type function)))

;; ����Ŭ�����ruleset-class �Υ��󥹥���
(defvar *current-ruleset* (make-instance *base-ruleset-class-name*))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; rule �ե�������ɤ߹���
(defun get-ruleset-modulename (ruleset)
  (string-downcase (string ruleset)))
(defmacro rule:require-ruleset (ruleset)
  `(eval-when (:compile-toplevel :load-toplevel :execute)
     (with-package :rule
       (scr:require (get-ruleset-modulename ,ruleset)
                    *rule-path* "rule"))))

;; (symbol | ruleset-instance)->ruleset-instance
(defun ensure-ruleset-instance (ruleset-name-or-instance &rest initargs)
  #+comment (assert (or (symbolp ruleset-name-or-instance)
                        (typep ruleset-name-or-instance *base-ruleset-class-name*)) )
  (cond
   ((symbolp ruleset-name-or-instance)
    (with1 class-sym (ruleset-class-symbol ruleset-name-or-instance)
      (if initargs
          (progn
            (unless (find-class class-sym nil)
              (rule:require-ruleset class-sym))
            (apply #'make-instance class-sym initargs))
        (ruleset-default-object class-sym))))
   (t #+comment (typep ruleset-name-or-instance *base-ruleset-class-name*)
    (when initargs
      (warn "Initargs ~S are ignored." initargs))
    ruleset-name-or-instance)))

;; Ŭ�����ruleset���ѹ�
(defmacro with-ruleset (ruleset-instance &body body)
  `(let ((*current-ruleset* ,ruleset-instance))
     ,@body))

;; �ǥե���Ȥ�entry: entry��̵���ݤΥ��顼��Ф�
(defun error-no-entry (dummy)
  (declare (ignore dummy))
  (error "~S has no entry point specified." *current-ruleset*))

;; default-handler��ƤӽФ�
(defun do-otherwise (x &optional (ruleset *current-ruleset*))
  (funcall (slot-value (the #.*base-ruleset-class-name* (ensure-ruleset-instance ruleset))
                       'rule:default-handler)
           x))

;; ruleset̾ -> class̾
(defun ruleset-class-symbol (sym)
  (declare (symbol sym))
  (immigrate-package sym *rule-class-package*))

;; (ruleset-class-symbolŬ�Ѻ�)ruleset̾ -> �ǥե���Ȥ�ruleset object
;; memoize�ˤ�ꡤưŪ���ɤΥ����å���make-instance��ʣ����¹Ԥ����
(defun ruleset-default-object (class-sym)
  (declare (symbol class-sym))
  (rule:require-ruleset class-sym)
  (make-instance class-sym))
(setf (symbol-function 'ruleset-default-object) 
  (memoize #'ruleset-default-object :test #'eq :size 50 :rehash-size 2))

;; rule̾ -> method̾
(defun rule-method-symbol (sym)
  (intern (string+ "<" (symbol-name sym) ">")
	  *rule-class-package*))

;; rule̾ -> defun̾
(defun rule-function-symbol (sym) sym)
(defun rule-probe-function-symbol (sym)
  (symbol+ sym :?))
(defun rule-warning-function-symbol (sym)
  (symbol+ sym :!))

;; method�ΰ�����defrule�����Τ��餳��̾���ǻ��ȡ�
(defun x-var ()
  (intern "X" *package*))

;;;; ruleset, rule ���������ĥ�ѥޥ���

;; define-ruleset
(defmacro rule:define-ruleset (name parents &body parameters)
  `(progn
     (eval-when (:compile-toplevel :load-toplevel :execute)
       ,@(loop    ; �ƥ롼�������ե���������
             for rs in (mapcar #'ruleset-class-symbol parents)
             collect `(rule:require-ruleset ',rs)))
     (provide ,(get-ruleset-modulename name))
     (defclass ,(ruleset-class-symbol name)
         ,(or (mapcar #'ruleset-class-symbol parents)
           (list *base-ruleset-class-name*))
       ,(loop for (p v) in parameters
            collect `(,p :initform ,v
                         :initarg ,(immigrate-package p "KEYWORD"))))
     (defun ,(ruleset-class-symbol name)
         (sc-code-or-filename &rest initargs)
       (apply #'rule:apply-rule
              sc-code-or-filename ',(ruleset-class-symbol name)
              initargs))
     ))

;; defrule
(defun rulemethod-args (ruleset)
  `(,(x-var) (,*ruleset-arg* ,(ruleset-class-symbol ruleset))))
(defmacro rule:defrule (name-opt ruleset &body pats-act-list)
  (let* ((name (if (consp name-opt) (car name-opt) name-opt))
         (options (when (consp name-opt) (cdr name-opt)))
         (memoize-p (member :memoize options)))
    `(progn
       (unless (fboundp ',(rule-function-symbol name))
         ;; <rule-name>
         ;; �桼���Ϣ��δؿ���Ȥäƴ���Ū��method ��Ƥ֡�
         ;; method ��ľ�ܤ��Ȥ���������������˥��饹���֥������Ȥ���ꤷ�ʤ��Ȥ����ʤ���
         (defun ,(rule-function-symbol name)
             (x &optional (ruleset-name-or-instance *current-ruleset* r) &rest initargs)
           (if r
               (with-ruleset (apply #'ensure-ruleset-instance
                                    ruleset-name-or-instance initargs)
                 (,(rule-method-symbol name) x *current-ruleset*))
             (,(rule-method-symbol name) x *current-ruleset*)))
         ;; for optimization
         (define-compiler-macro ,(rule-function-symbol name) (&whole form x &rest args)
           (declare (ignore args))
           (if (cddr form)
               form
             (list ',(rule-method-symbol name) x '*current-ruleset*)))
         (export ',(rule-function-symbol name))
         ;; <rule-name>? rule::no-match �Τ�����nil���֤�
         (defun ,(rule-probe-function-symbol name) (&rest args)
           (let ((ret-list (multiple-value-list (apply #',(rule-function-symbol name) args))))
             (when (eq 'rule::no-match (car ret-list))
               (rplaca ret-list nil))
             (values-list ret-list)))
         (export ',(rule-probe-function-symbol name))
         ;; <rule-name>! rule::no-match �ʤ�warning��Ф�
         (defun ,(rule-warning-function-symbol name) (&rest args)
           (let ((ret-list (multiple-value-list (apply #',(rule-function-symbol name) args))))
             (when (eq 'rule::no-match (car ret-list))
               (iwarn "Any patterns in `~S' did not match ~S" ',name (car args)))
             (values-list ret-list)))
         (export ',(rule-warning-function-symbol name))
         )
       ;; method����
       (,(if memoize-p 'defmethod-memo 'defmethod) ,(rule-method-symbol name) ,(rulemethod-args ruleset)
         ,.(when memoize-p (list (x-var)))
         (block ,name
           (flet ,(make-call-next-rule)
             (declare (ignorable #'rule:call-next-rule))
             (rule:cond-match ,(x-var)
                              ,@pats-act-list
                              (otherwise
                               (do-otherwise ,(x-var) ',ruleset))))))
       )
    ))

;; extendrule
(defmacro rule:extendrule (name-opt ruleset &body pats-act-list)
  (let* ((name (if (consp name-opt) (car name-opt) name-opt))
         (options (when (consp name-opt) (cdr name-opt)))
         (memoize-p (member :memoize options)))
    `(progn
       (,(if memoize-p 'defmethod-memo 'defmethod)
           ,(rule-method-symbol name) ,(rulemethod-args ruleset)
         ,.(when memoize-p (list (x-var)))
         (flet ,(make-call-next-rule)
           (declare (ignorable #'rule:call-next-rule))
           (block ,name
             (rule:cond-match ,(x-var)
                              ,@pats-act-list
                              (otherwise (call-next-method))))))) ; ������defrule�Ȱ㤦
    ))

;; ���Υ롼���桼�����տ�Ū�˸ƤӽФ�����ζɽ�ؿ�
;; ��flet���������Ǥ����
(defun make-call-next-rule ()
  (let ((x-var (gensym "X"))
        (xp-var (gensym "XP")))
    `((rule:call-next-rule (&optional (,x-var nil ,xp-var))
        (if ,xp-var
            (call-next-method ,x-var *current-ruleset*)
          (call-next-method))))
    ))

;; �ѷ���§�Υѥ�᡼���ؤΥ�������
;; �ʼºݤϥ��饹���󥹥��󥹤Υ��ФؤΥ���������
(defmacro rule:ruleset-param (slot-name)
  `(slot-value *current-ruleset* ,slot-name))

;; entry��ƤӽФ�
(defun rule:apply-rule (sc-code-or-filename ruleset-name-or-instance &rest initargs)
  (with-ruleset (apply #'ensure-ruleset-instance
                       ruleset-name-or-instance initargs)
    (funcall (symbol-function (slot-value *current-ruleset* 'rule:entry))
             (if (or (stringp sc-code-or-filename)
                     (pathnamep sc-code-or-filename))
                 (sc-file:read-sc-file sc-code-or-filename)
               sc-code-or-filename))))
