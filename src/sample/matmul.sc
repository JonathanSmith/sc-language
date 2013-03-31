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

(deftype mat (array int 2 2))
(decl printf (fn int (ptr (const char)) va-arg))

;(private pa int)
;(private pb long)

((matmul a b c) (fn void mat mat mat)
  (defs int i j k)
  (for ( (def i int 0) (<= i 1) (inc i) )
   (for ( (def j int 0) (<= j 1) (inc j) )
    (= (aref c i j) 0)))
  (for ( (def i int 0) (<= i 1) (inc i) )
   (for ( (def j int 0) (<= j 1) (inc j) )
    (for ( (def k int 0) (<= k 1) (inc k) )
     (deftype l int)
     (+= (aref c i j) (* (aref a i k) (aref b k j))))))
  
  (def k__2 unsigned-char)

  (return))

((main) (fn int)
 (let ((defs mat (a (array (array 1 2) (array 3 4)))
                 (b (array (array 5 6) (array 7 8))) c))
  (matmul a b c)
  (printf "a:%d %d %d %d \\n" 
    (aref a 0 0) (aref a 0 1) (aref a 1 0) (aref a 1 1))
  (printf "b:%d %d %d %d \\n" 
    (aref b 0 0) (aref b 0 1) (aref b 1 0) (aref b 1 1))
  (printf "c:%d %d %d %d \\n" 
    (aref c 0 0) (aref c 0 1) (aref c 1 0) (aref c 1 1))
  (return)))
