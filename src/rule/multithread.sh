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

;;; Header file for MT-SC, automatically included by multithread.rule

(c-exp "#include<stdio.h>")
(c-exp "#include<stdlib.h>")

(%ifndef NESTFUNC-TAG
	 ((%defconstant NESTFUNC-TAG fn)))

(decl (struct _thstelm))

;; ��³������Ҵؿ��θƤӽФ���ͳ
(deftype reason enum rsn-cont rsn-retval)

;; ��³������Ҵؿ��Υݥ���
(deftype
    cont-f 
    (ptr (NESTFUNC-TAG (ptr void) (ptr (struct _thstelm)) reason)))

;; ����åɤξ���
(def (enum _stat)
     ;; �����ǡ�����Ū��³��ͭ��
     thr-new-suspended
     ;; �¹Բ�ǽ�ǡ�����Ū��³��ͭ��
     thr-new-runnable
     ;; �����ǡ�����Ū��³�Τ�ͭ��
     thr-suspended
     ;; �¹Բ�ǽ�ǡ�����Ū��³�Τ�ͭ��
     thr-runnable
     ;; ����Ū��³(cont-f c)��̵��
     thr-scheduled)

;; ����åɴ����ѥ����å�������
(def (struct _thstelm)
     (def c cont-f)
     (def stat (enum _stat)))

(deftype thstelm (struct _thstelm))

(deftype thst-ptr (ptr (struct _thstelm)))
(deftype cont thst-ptr)

;; ����åɴ����ѥ����å�
(def thst (array thstelm 65536))

;; ����åɴ����ѥ����å��Υȥå�
(def thst-top thst-ptr thst)

(deftype schdexit (ptr (NESTFUNC-TAG void)))

;; �������塼�����ɽ�æ����
(def cur-schd-exit schdexit 0)
(def cur-schd-thst-top thst-ptr thst)

(def scheduling (fn void)
     (def L0 --label--)
     ;;���Υ������塼��ξ���
     (def prev-exit schdexit cur-schd-exit)
     (def prev-thst-top thst-ptr cur-schd-thst-top)
     ;;���Υ��������ξ���
     (def mythst-top thst-ptr thst-top)
     (def nonlocalexit (NESTFUNC-TAG void) (goto L0))

     (label L0 nil)
     (= cur-schd-exit nonlocalexit)
     (= cur-schd-thst-top (= thst-top mythst-top))
     (while 1
       (let ((cp thst-ptr))
	 ;;�����Ǹ��Υ������塼��ؤ���ɽ�æ�Ф��ߤ�
	 (for ((= cp prev-thst-top)
	       (< cp mythst-top)
	       (inc cp))
	    (if (!= (fref cp -> stat) thr-scheduled) (break))
	    ;; �֤����� thr-scheduled �ʤ�
	    (if (== cp mythst-top) (if prev-exit (prev-exit)))))

       ;; runnable�ʥ���åɤ�õ��
       (let ((cp thst-ptr)
	     (cc cont-f))
	 (for ((= cp (- thst-top 1))
	       (>= cp thst)
	       (dec cp))
	      (if (or (== (fref cp -> stat) thr-runnable)
		      (== (fref cp -> stat) thr-new-runnable))
		  (break)))
	 (if (< cp thst)
	     (begin
	      ;; ���Ĥ���ʤ��ä��Ȥ���¾�Υץ��å�������׵��������٤�
	      ;; ����ϲ��⤷�ʤ�
	      (c-exp "fprintf(stderr, ~A)" "No Active thread!~%")
	      (c-exp "exit(1)")
	      ))
	 (do-while (== (fref cp -> stat) thr-runnable)
	   (= cc (fref cp -> c))
	   (= (fref cp -> c) 0)
           (= (fref cp -> stat) thr-scheduled)
	   (cc cp rsn-cont)))
       ;;ľ����new-runnable�ʤ�pop����������������ܤ�
       (if (and (> thst-top thst)
		(== (fref (- thst-top 1) -> stat) thr-new-runnable))
	   (begin (dec thst-top) (break))))

     ;; ���Υ������塼��ξ�����᤹
     (= cur-schd-exit prev-exit)
     (= cur-schd-thst-top prev-thst-top))

;; thread-resume
(def (thr-resume cp) (fn void thst-ptr)
     (if (== (fref cp -> stat) thr-suspended)
	 (= (fref cp -> stat) thr-runnable)
       (if (== (fref cp -> stat) thr-new-suspended)
	   (= (fref cp -> stat) thr-new-runnable))))
