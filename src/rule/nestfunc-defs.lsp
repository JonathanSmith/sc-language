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

;;; Utilities for nestfunc.rule
(provide "NESTFUNC-DEFS")

(defpackage "NESTED-FUNCTION"
  (:nicknames "LW" "NESTFUNC")
  (:export :*frame-alist* :*current-func* :*estack-size* :*all-in-estack*
           :make-finfo :top-level-p :finfo-name :finfo-parent-func :finfo-ret-type
           :finfo-argp :finfo-label-list :finfo-var-list :finfo-tmp-list
           :finfo-nf-list :finfo-estack-var
           :with-nestfunc-environment
           :add-global-func
           :thread-origin-p :get-frame :get-frame-name
           :estack-variable-p :static-variable-p :howmany-outer
           :make-frame-def :make-all-frame-decls
           :with-external-decl :add-static-var-def :flush-static-var-defs
           :add-frame-def :add-nestfunc-def :flush-frame-defs :flush-nestfunc-defs
           :with-new-block :add-local-decl :flush-local-decls
           :with-block-item :add-precedent :flush-precedents
           :finfo-add-local-label :finfo-add-local :finfo-next-call-id :finfo-add-resume-label
           :finfo-add-nestfunc
           :make-resume :make-init-efp-esp :make-parmp-init :save-args-into-estack :make-extid
           :make-normalize-nf :make-frame-save :make-frame-resume
           :make-suspend-return :finfo-find-local-label :combine-ret-list
           :simple-exp-p)
  (:use "RULE" "CL" "SC-MISC")
  (:shadow cl:declaration))
(in-package "NESTED-FUNCTION")


(defstruct finfo 
  name                                  ;�ؿ�̾
  parent-func                           ;�ƴؿ���finfo��¤�Ρ���nil iff ����Ҵؿ���
  ret-type                              ;�֤��ͤη�
  argp                                  ;argp����/���� (=����Ҵؿ��ƤӽФ���̵ͭ)
  ;; (<�������֤򼨤���٥�̾> . <�ե졼�������ѥ�����>) �Υꥹ��(�ս�)
  label-list
  ;; ( <symbol> . <texp> )
  ;; frame�ˤ� var-list #|�� tmp-list��ξ����|# �����
  ;; ��nf-list �� orig-name ��������
  ;; frame-save, frame-resume ��var-list�Τ�
  ;; tmp-list �����פ���
  var-list                              ;�̾�Υ������ѿ��Υꥹ�ȡܴؿ��Υݥ�����¸��
  tmp-list                              ;����ѿ��Υꥹ�ȡ�call���ΰ���������Ҵؿ��ݥ�����¸�ѡ�
  nf-list                               ;������줿����Ҵؿ��Υꥹ�� ( <orig-name> . <ext-name> )
  ;; ����Ū�����å��򻲾Ȥ���������ѿ���list of <id(symbol)>
  ;; var-list�Ƚ�ʣ������Ҵؿ��� nf-list�Ǵ�������ΤǤ����ˤ�����ʤ�
  ;; search-ptr �Ǥμ������ˤˤ�ꡤvar-list�Ǥʤ���Τ��������롥
  estack-var
  ;; static��������줿�ѿ� (<orig-name> . <ext-name>)��var-list�Ƚ�ʣ��
  static-var
  ;; �ɽ��٥�Υꥹ��(def ,id __label__)�����������Ҵؿ�æ����
  ;; (<��٥�̾> . <����������>)������ȵս�
  local-label
  )

;; �ե졼�๽¤�Τδ���
(defstruct frame-struct-info
  name                                  ; ��¤��̾ (SC��id)
  func-name                             ; �б�����ؿ�̾ (SC��id)
  )

;;; global�ؿ�̾
(defvar *global-funcs* '())

;;; �ؿ��ե졼��ι�¤�ξ���
;;; ( <�ؿ�̾(symbol)> . <��¤�ξ���> ) �Υꥹ��
;;; <��¤�ξ���> := ( <��¤��̾> ) 
(defvar *frame-alist* '() )
;;; ���ߤ���ؿ��ξ���
(defvar *current-func* nil)

(defvar *estack-size* 65536)
(defvar *all-in-estack* nil)

;;;; �Ķ�����
(defmacro with-nestfunc-environment (&body body)
  `(let ((*global-funcs* '())
         (*estack-size* (ruleset-param 'rule::estack-size))
         (*all-in-estack* (ruleset-param 'rule::all-in-estack))
         (*frame-alist* '())
         (*current-func* nil))
     ,@body))


;;;; �ؿ�

(defun add-global-func (fid)
  (push fid *global-funcs*))

(defun global-func-p (fid)
  (member fid *global-funcs* :test #'eq))

;;; �ޥ������åɴĶ��ǡ������å��κǽ�Υե졼���Ƚ�Ǥ�����
(defun thread-origin-p (finfo-or-fid)
  (let ((fid (if (symbolp finfo-or-fid)
                 finfo-or-fid
               (finfo-name finfo-or-fid))))
    (or (eq ~main fid)
        (eq ~thread-origin fid))))      ; ���פ���


;;; �ؿ�̾��*frame-alist*����õ���ƴؿ��ե졼��ι�¤�ξ�������롣
;;; ̤��Ͽ�ξ�����Ͽ���ơ���Ͽ������¤�ξ�����֤���
(defun get-frame (x)
  (let* ((asc (assoc x *frame-alist* :test #'eq)))
    (if asc
        (cdr asc)
      (let* ((strx (identifier0! x :sc2c))
             (frame-name (generate-id (string+ strx "_frame")))
             (frame-info (make-frame-struct-info :name frame-name :func-name x)))
        (push (cons x frame-info) *frame-alist*)
        frame-info))))

;;; �ؿ�̾=>�ؿ��Υե졼�๽¤��̾
(defun get-frame-name (fname)
  (frame-struct-info-name (get-frame fname)))

;;; ���ؿ��ʿƤϴޤޤʤ��ˤ�local-variable����
;;; tmp-list��Τ�Ρ�����Ҵؿ��ϸ����оݤǤϤʤ���
(defun local-variable-p (id &optional (finfo *current-func*))
  (and *current-func*
       (assoc id (finfo-var-list finfo) :test #'eq)))

;;; ���ؿ��ʿƤϴޤޤʤ��ˤ�����Ū�����å����ͤ�����local-variable����
(defun estack-variable-p (id &optional (finfo *current-func*)
                                       (skip-lv-check nil)) ; local-variable-p �Υ����å����ά
  (and (or skip-lv-check (local-variable-p id finfo))
       (member id (finfo-estack-var finfo) :test #'eq)))

;;; ���ؿ��ʿƤϴޤޤʤ��ˤ�static��������줿local-variable����
;;; �����ʤ顤ext-id���֤���
(defun static-variable-p (id &optional (finfo *current-func*)
                                       (skip-lv-check nil)) ; local-variable-p �Υ����å����ά
  (and (or skip-lv-check (local-variable-p id finfo))
       (cdr (assoc id (finfo-static-var finfo) :test #'eq))))

;;; ���ؿ�(=0)���餤���ĳ��δؿ���������줿 local-variable/nestfunc ��?
;;; ���Ĥ���ʤ���� -1
;;; �����֤��ͤ� local-varriable-> :var, nestfunc-> :nestfunc
;;; �軰�֤��ͤ� ���Ĥ��ä��ؿ���finfo
;;; ����֤��ͤ� local-variable-p/nestfunc-extid ���֤���
(defun howmany-outer (id &optional (finfo *current-func*))
  (labels ((rec (curfunc acc)
             (acond
              ((null curfunc)
               -1)
              ((local-variable-p id curfunc)
               (values acc :var finfo it))
              ((nestfunc-extid id curfunc)
               (values acc :nestfunc finfo it))
              (t (rec (finfo-parent-func curfunc) (1+ acc))) )))
    (rec finfo 0)))

;;; Ϳ����줿�ؿ����󤫤�ե졼�๽¤�Τ��������
(defun make-frame-def (fi)
  (let* ((frm-info (get-frame (finfo-name fi)))
         (frame-name (frame-struct-info-name frm-info))
         (member-list (append (finfo-var-list fi)
                             ;; (finfo-tmp-list fi)
                             (mapcar #'(lambda (x) (cons (car x) ~closure-t))
                                     (finfo-nf-list fi))))
         (member-defs (mapcar #'(lambda (x) ~(def ,(car x) ,(cdr x)))
                              member-list)))
    ~(def (struct ,frame-name)
         (def tmp-esp (ptr char))       ; ����ϡ����Ф���Ƭ
       (def argp (ptr char))
       (def call-id int)
       ,@member-defs)))

;;; ���Ƥδؿ��ե졼�๽¤�Τ��������
(defun make-all-frame-decls ()
  (nreverse                             ; nreverse��ɬ�ܤǤϤʤ�
   (loop for (fn-name . frm-info) in *frame-alist*
       collect (with1 frame-name (frame-struct-info-name frm-info)
                 ~(decl (struct ,frame-name))))) )

;;; �ȥåץ�٥���ɲä�������ν���
(defvar *static-var-defs* ())
(defvar *frame-defs* ())
(defvar *nestfunc-defs* ())
(defmacro with-external-decl (&body body)
  `(let ((*static-var-defs* ()) (*frame-defs* ()) (*nestfunc-defs* ()))
     ,@body))
(defun add-static-var-def (decl)
  (push decl *static-var-defs*))
(defun flush-static-var-defs ()
  (prog1 (nreverse *static-var-defs*)
    (setq *static-var-defs* ())))
(defun add-frame-def (decl)
  (push decl *frame-defs*))
(defun flush-frame-defs ()
  (prog1 (nreverse *frame-defs*)
    (setq *frame-defs* ())))
(defun add-nestfunc-def (decl)
  (push decl *nestfunc-defs*))
(defun flush-nestfunc-defs ()
  (prog1 (nreverse *nestfunc-defs*)
    (setq *nestfunc-defs* ())))

;;; �֥�å�����Ƭ���ɲä�������ν���
(defvar *additional-local-decls* ())
(defmacro with-new-block (&body body)
  `(let ((*additional-local-decls* ())) ,@body))
(defun add-local-decl (decl)
  (push decl *additional-local-decls*))
(defun flush-local-decls ()
  (prog1 (nreverse *additional-local-decls*)
    (setq *additional-local-decls* ())))

;;; ��ʸ��ľ�����ɲä���ʸ�ν���
(defvar *precedents* ())
(defmacro with-block-item (&body body)
  `(let ((*precedents* ())) ,@body))
(defun add-precedent (item)
  (push item *precedents*))
(defun flush-precedents ()
  (prog1 (nreverse *precedents*)
    (setq *precedents* ())))

;;; ���ȥåץ�٥�ˤ��뤫�ɤ�����Ƚ��
(defun top-level-p (&key (finfo *current-func*))
  (not finfo))

;;; --local-- ��������줿�ɽ��٥���ɲ�
;;; cons �� cdr ���ϥե졼�������ѥ����ɤǡ��夫���ɲ�
(defun finfo-add-local-label (id &key (finfo *current-func*))
  (push (cons id nil) (finfo-local-label finfo)))

;;; *current-func*���ѿ�������ɲä��ơ�declarationʸ���֤�
(defun finfo-add-local (id texp mode &key (init nil) (finfo *current-func*))
  ;; mode�� :var or :temp
  (when finfo
    (case mode
      ((:var)                           ; ��estack-var�Ǥʤ���С�save/resume ���о�
       (when (let ((ttexp (remove-type-qualifier texp)))
               (or (and (listp ttexp)
                        (eq ~array (car ttexp)))
                   *all-in-estack*))
         (pushnew id (finfo-estack-var finfo) :test #'eq))
       (push (cons id texp) (finfo-var-list finfo)))
      ((:tmp)                           ; save/resume ���оݤˤʤ�ʤ�
       (push (cons id texp) (finfo-tmp-list finfo)))
      ((:static)                        ; ���˽Ф���frame�ˤ�����ʤ���
       (let ((ext-id (generate-id
                      (string+ (identifier0! id :sc2c) "_in_" 
                               (identifier0! (finfo-name finfo) :sc2c)))))
         (push (cons id texp) (finfo-var-list finfo))
         (push (cons id ext-id) (finfo-static-var finfo))
         (setq id ext-id)))             ; ̾������ͤ��ʤ��褦���ѹ�
      ((:system)                        ; ����ѿ����ä������Ѥʤ���
       )
      (otherwise
       (error "unexpected value of 'mode'(~s)" mode))))
  (if init
      ~(def ,id ,texp ,init)
    ~(def ,id ,texp)))

;;; *current-func* ������Ҵؿ�������ɲ�
(defun finfo-add-nestfunc (id extid &optional (finfo *current-func*))
  (push (cons id extid)
        (finfo-nf-list finfo)) )

;;; ����call-id�ο���
(defun finfo-next-call-id (&optional (finfo *current-func*))
  (length (finfo-label-list finfo)))

;;; �������֤򼨤���٥���ɲá���٥�̾���֤���
(defun finfo-add-resume-label (&optional (finfo *current-func*) (base-name "L_CALL"))
  (with1 label-id (rule:generate-id base-name)
    (push (cons label-id nil) (finfo-label-list finfo))
    label-id))

;;; Ϳ����줿�ؿ����󤫤�����������Ԥ�statement����
(defun make-resume (fi)
  (unless (or (finfo-label-list fi)
              (finfo-local-label fi))
    (return-from make-resume
      (list ~(label LGOTO nil))))
  (let ((reconst-impossible (or (eq ~main (finfo-name fi))
                                (finfo-parent-func fi)
                                *all-in-estack*))
                                        ; �����å����Ѥ�ľ������������ʤ�
        (case-goto
         (append
          ;; ����Ҵؿ��ƤӽФ���λ�������
          (do ((ret nil)
               (k 0 (1+ k))
               (lb (reverse (finfo-label-list fi)) (cdr lb)))
              ((endp lb) (apply #'append (nreverse ret)))
            (push ~((case ,k)
                    ,@(cdar lb) 
                    (goto ,(caar lb)))
                  ret))
          ;; goto�ˤ������Ҵؿ�����ƴؿ��ؤ�æ����
          (do ((ret nil)
               (k -1 (1- k))
               (lb (reverse (finfo-local-label fi)) (cdr lb)))
              ((endp lb) (apply #'append (nreverse ret)))
            (push ~((case ,k)
                    ,@(cdar lb) 
                    (goto ,(caar lb)))
                  ret))))
        (frame-type ~(struct ,(get-frame-name (finfo-name fi)))))
    (list
     ~(if ,(if reconst-impossible
               ~0
             ~esp-flag)
          (begin
           ,@(unless reconst-impossible
               ~( (= esp (cast (ptr char)
                           (bit-xor (cast size-t esp) esp-flag)))
                  (= efp (cast (ptr ,frame-type) esp))
                  (= esp (aligned-add esp (sizeof ,frame-type)))
                  (= (mref-t (ptr char) esp) 0) ))
           (label LGOTO
                  (switch (fref (mref efp) call-id) ,@case-goto))
           ,@(when (finfo-label-list fi)
               ~( (goto ,(caar (last (finfo-label-list fi)))) )))))))

;;; efp(xfp)�����ꤪ��� esp��ե졼�ॵ����ʬ��ư������
(defun make-init-efp-esp (fi)
  (let ((frame-type  ~(struct ,(get-frame-name (finfo-name fi)))))
    (list*
     ~(= efp (cast (ptr ,frame-type) esp))
     ~(= esp (aligned-add esp (sizeof ,frame-type)))
     ~(= (mref-t (ptr char) esp) 0)
     (when (and *all-in-estack* (finfo-parent-func fi))
       (list ~(= (fref efp -> xfp) xfp) )))
    ))

;;; parmp �ν����
(defun make-parmp-init (&optional (all-in-estack *all-in-estack*))
  ~(cast (ptr char)
     ,(if all-in-estack
          ~esp
        ~(bit-xor (cast size-t esp) esp-flag))) )

;;; ��*all-in-estack*���˰������ͤ�estack����¸
(defun save-args-into-estack (argid-list argtexp-list
                              &optional (finfo *current-func*))
  ;; ����äȼ�ȴ���Ƿ����� (the)�ʤ�
  (mapcar #'(lambda (id texp)
              (if (finfo-parent-func finfo)
                  ~(= (fref efp -> ,id) (pop-arg ,texp parmp)) 
                ~(= (fref efp -> ,id) ,id) ))
          argid-list
          argtexp-list) )

;;; ����Ҵؿ���id -> �ȥåץ�٥�˰ܤ����ؿ���id
(defun make-extid (id &optional (pfinfo *current-func*))
  (generate-id (string+ (identifier0! id :sc2c) "_in_"
                        (identifier0! (finfo-name pfinfo) :sc2c))) )

;;; id�����ߤδؿ��ʿƤϽ��������������줿����Ҵؿ�����
;;; �⤷�����ʤ顤ext-name ���֤�
(defun nestfunc-extid (id &optional (finfo *current-func*))
  (and *current-func*
       (cdr (assoc id (finfo-nf-list finfo) :test #'eq))))

;;; ����Ҵؿ��λ��� -> etack�ؤλ���
;;; ��pfinfo: �ƴؿ������
(defun nestfunc-in-estack (fid &optional (pfinfo *current-func*))
  (declare (ignore pfinfo))
  ~(ptr (fref efp -> ,fid)))

;;; Ϳ����줿�ؿ����󤫤�����Ҵؿ������������륳���ɤ���
(defun make-normalize-nf (&optional (fi *current-func*))
  (let ((nf-list (finfo-nf-list fi)))
    (apply #'nconc
           (mapcar
            #'(lambda (x) 
                ~( (= (fref efp -> ,(car x) fun)
                      ,(cdr x))
                   (= (fref efp -> ,(car x) fr)
                      (cast (ptr void) efp)) ))
            nf-list))))

;;; Ϳ����줿�ؿ����󤫤�ե졼��������¸���륳���ɤ���
(defun make-frame-save (&optional (fi *current-func*))
  (mapcar
   #'(lambda (x)
       ~(= (fref efp -> ,(car x)) ,(car x)))
   (remove-if #'(lambda (x)
                  (or (estack-variable-p (car x) fi t)
                      (eq ~closure-t (cdr x))))
              (finfo-var-list fi))))

;;; Ϳ����줿�ؿ����󤫤�ե졼���������褹�륳���ɤ���
(defun make-frame-resume (&optional (fi *current-func*))
  (mapcar
   #'(lambda (x) 
       ~(= ,(car x) (fref efp -> ,(car x))))
   (remove-if #'(lambda (x)
                  (or (estack-variable-p (car x) fi t)
                      (eq ~closure-t (cdr x))))
              (finfo-var-list fi))))

;;; Ϳ����줿�ؿ����󤫤�ؿ������Ѥ�return���������륳���ɤ���
(defun make-suspend-return (&optional (fi *current-func*))
  (cond ((finfo-parent-func fi)
         ;;~(return (fref efp -> tmp-esp)))
         (error "make-suspend-return called in lightweight-func"))
        ((eq ~void (finfo-ret-type *current-func*))
         ~(return))
        (t
         ~(return (SPECIAL ,(finfo-ret-type *current-func*))))))

;;; Ϳ����줿��٥�̾�����ƴؿ��ζɽ��٥�Ȥ����������Ƥ��뤫Ĵ�٤롣
;;; �������Ƥ��ʤ����,�֤��ͤ�nil���������Ƥ���С�
;;; (values <��ʬ����ߤƲ����ܤοƴؿ����������Ƥ�����>
;;;         <������� ( <label> . <��������> )> 
;;;         <���Υ�٥뤬�ؿ���ǲ����ܤ�push���줿��Τ�>)
(defun finfo-find-local-label (lid &optional (fi *current-func*) &aux (lids (identifier0! lid :sc2c)))
  (labels ((find-local-label-tail (cfi acc &aux memb)
             (cond ((null cfi)
                    nil)
                   ((let* ((memb0 (member 
                                   lids
                                   (finfo-local-label cfi)
                                   :test #'string=
                                   :key #'(lambda (x) (identifier0! (car x) :sc2c)))))
                      (setq memb memb0))
                    (values acc (car memb) (length memb)))
                   (t
                    (find-local-label-tail
                     (finfo-parent-func cfi) (1+ acc))))))
    (find-local-label-tail fi 0)))

;; begin�Ȥ���(Nfb0 body)���֤��ͤ��顢
;; begin���Τ�Τ��֤��ͤ��롣
;; ((r1-1 r1-2 r1-3 r1-4) ... (rn-1 rn-2 rn-3 rn-4))
;; => ( (,@r1-1 ... ,@rn-1)
;;      (,@r1-2 ... ,@rn-2) 
;;      nil
;;      (,@prev-4th ,@r1-3 ,r1-4 ... ,@rn-3 ,rn-4 ) )
(defun combine-ret-list (ret-list &optional prev-4th)
  (let ((fst (mapcar #'first ret-list))
        (scd (mapcar #'second ret-list))
        (thd-4th (mapcar
                  #'(lambda (x) ~(,@(third x) ,(fourth x)))
                  ret-list)))
    (list (apply #'append fst)
          (apply #'append scd)
          nil
          (remove nil (apply #'append prev-4th thd-4th)))))

;; ����ѿ���Ȥ�ɬ�פ��ʤ����Ĥޤ�
;; * ����Ҵؿ��ƽФ�����ѹ����ä����ʤ�(permit-change=nil����
;; * �����Ѥ򵯤����ʤ�
;; ���Ȥ��ݾڤǤ��뼰
(defun simple-exp-p (the-exp &optional (permit-change nil))
  (let ((type (second the-exp))
        (exp (third the-exp)))
    (or (and (symbolp exp) permit-change)
        (and (global-func-p exp) (not (local-variable-p exp)))
        (eq 'type::undefined type)
        (sc-number exp)
        (sc-character exp)
        (sc-string exp))))
