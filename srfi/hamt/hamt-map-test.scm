;;;; HAMT Map Tests

;;; Copyright MMXV-MMXVII Arthur A. Gleckler.  All rights reserved.

;; Permission is hereby granted, free of charge, to any person
;; obtaining a copy of this software and associated documentation
;; files (the "Software"), to deal in the Software without
;; restriction, including without limitation the rights to use, copy,
;; modify, merge, publish, distribute, sublicense, and/or sell copies
;; of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:

;; The above copyright notice and this permission notice shall be
;; included in all copies or substantial portions of the Software.

;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
;; EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
;; MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
;; NONINFRINGEMENT.  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
;; HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
;; WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
;; DEALINGS IN THE SOFTWARE.

(define (run-hamt-map-tests)
  (test-begin "hamt-map")

  (define (assert-phm= phm alist)
    (test-equal = (length alist) (phm/count phm))
    (do-list (a alist)
      (test-assert (phm/contains? phm (car a)))
      (test-assert (= (cdr a) (phm/get phm (car a) #f)))))

  (test-group "(persistent-hash-map make-phm alist)"
    (let* ((alist '(("a" . 1) ("b" . 2)))
	   (phm (make-phm string-hash string=? alist)))
      (test-assert (not (hamt/mutable? phm)))
      (assert-phm= phm alist)))

  (test-group "(persistent-hash-map make-phm phm/count)"
    (let ((phm (make-phm string-hash string=? '(("a". 1) ("b" . 2)))))
      (test-assert (= 2 (phm/count phm)))))

  (test-group "(persistent-hash-map phm/empty?)"
    (test-assert (phm/empty? (make-phm string-hash string=?)))
    (test-assert (not (phm/empty? (make-phm string-hash string=? '(("a")))))))

  (define (phm-random-test put remove transform)
    (define (sort-alist alist)
      (sort alist (lambda (a1 a2) (string<? (car a1) (car a2)))))
    (let ((contents (make-string-hash-table))
	  (deleted-keys (make-string-set))
	  (deletion-odds 5)
	  (max-key-length 5)
	  (operations 100))
      (define (random-key)
	(let ((size (1+ (random max-key-length))))
	  (with-output-to-string
	    (lambda ()
	      (do-times (i size)
		(write-char (make-char (+ 97 (random 26)) 0)))))))
      (define (fill-phm i phm)
	(let ((size (hash-table/count contents)))
	  (cond ((zero? i) phm)
		((and (not (zero? size))
		      (zero? (random deletion-odds)))
		 (let ((key (nth (random size) (hash-table/key-list contents))))
		   (set/add! deleted-keys key)
		   (hash-table/remove! contents key)
		   (fill-phm (-1+ i)
			     (remove phm key))))
		(else (let* ((key (random-key))
			     (datum (random 1000)))
			(set/remove! deleted-keys key)
			(hash-table/put! contents key datum)
			(fill-phm (-1+ i)
				  (put phm key datum)))))))
      (let ((phm (fill-phm operations
			   (transform (make-phm string-hash string=?)))))
	(test-assert (= (phm/count phm) (hash-table/count contents)))
	(hash-table/for-each contents
			     (lambda (key datum)
			       (test-assert (= datum (phm/get phm key -1)))
			       (test-assert (phm/contains? phm key))))
	(do-set (key deleted-keys)
	  (test-assert (= -1 (phm/get phm key -1)))
	  (test-assert (not (phm/contains? phm key))))
	(let ((ht-alist (hash-table->alist contents))
	      (phm-alist (phm->alist phm)))
	  (test-assert (equal? (sort-alist ht-alist)
			       (sort-alist phm-alist)))))))

  (test-group "(persistent-hash-map random pure)"
    (phm-random-test phm/put phm/remove (lambda (m) m)))

  (test-group "(persistent-hash-map random mutate)"
    (phm-random-test phm/put! phm/remove! phm/mutable))

  (test-group "(persistent-hash-map random mixed)"
    (define (flip mutate? phm)
      ((if mutate? phm/mutable phm/immutable) phm))
    (phm-random-test (let ((mutate? #t))
		       (lambda (phm key datum)
			 (set! mutate? (not mutate?))
			 ((if mutate? phm/put! phm/put)
			  (flip mutate? phm)
			  key
			  datum)))
		     (let ((count 0))
		       (lambda (phm key)
			 (set! count (remainder (1+ count) 3))
			 (let ((mutate? (zero? count)))
			   ((if mutate? phm/remove! phm/remove)
			    (flip mutate? phm)
			    key))))
		     (lambda (m) m)))

  (define (phm-remove-non-existent-test remove transform)
    (define (terrible-hash string) 0)
    (let ((phm (remove (transform (make-phm string-hash string=?))
		       "not-present")))
      (test-assert (zero? (phm/count phm)))
      (test-assert (not (phm/contains? phm "not-present")))
      (test-assert (not (phm/get phm "not-present" #f))))
    (let ((phm (remove (transform (phm/put (make-phm terrible-hash string=?)
					   "foo"
					   1))
		       "not-present")))
      (test-assert (= 1 (phm/count phm)))
      (test-assert (phm/contains? phm "foo"))
      (test-assert (not (phm/contains? phm "not-present")))))

  (test-group "(persistent-hash-map remove-non-existent pure)"
    (phm-remove-non-existent-test phm/remove (lambda (m) m)))

  (test-group "(persistent-hash-map remove-non-existent mutate)"
    (phm-remove-non-existent-test phm/remove! phm/mutable))

  (test-group "(persistent-hash-map phm/add-alist)"
    (let* ((alist '(("foo" . 1) ("bar" . 2) ("baz" . 3)))
	   (phm (phm/add-alist (make-phm string-hash string=?) alist)))
      (assert-phm= phm alist)))

  (test-group "(persistent-hash-map phm/add-alist!)"
    (let* ((alist '(("foo" . 1) ("bar" . 2) ("baz" . 3)))
	   (phm (phm/mutable (make-phm string-hash string=?))))
      (phm/add-alist! phm alist)
      (assert-phm= phm alist)))

  (define (phm-collision-test put remove transform)
    (define (sort-alist alist)
      (sort alist (lambda (a1 a2) (string<? (car a1) (car a2)))))
    (define (terrible-hash string)
      (cond ((string=? string "foo") 0)
	    ((string=? string "bar") 1)
	    (else 2)))
    (let* ((alist '(("foo" . 1) ("bar" . 2) ("baz" . 3) ("bat" . 4)
		    ("quux" . 5)))
	   (phm-1 (fold-left
		   (lambda (phm a) (put phm (car a) (cdr a)))
		   (transform (make-phm terrible-hash string=?))
		   alist))
	   (phm (put phm-1 "baz" 3)))
      (assert-phm= phm alist)
      (let ((phm-alist (phm->alist phm)))
	(test-assert (equal? (sort-alist alist)
			     (sort-alist phm-alist))))
      (let ((alist-minus-baz (del-assoc "baz" alist))
	    (phm-minus-baz (remove (transform phm) "baz")))
	(assert-phm= phm-minus-baz alist-minus-baz)
	(let ((phm-minus-nonexistent (remove phm-minus-baz "not-present")))
	  (test-equal = (phm/count phm-minus-nonexistent) (- (length alist) 1))
	  (let ((alist-minus-bat (del-assoc "bat" alist-minus-baz))
		(phm-minus-bat (remove phm-minus-nonexistent "bat")))
	    (assert-phm= phm-minus-bat alist-minus-bat))))))

  (test-group "(persistent-hash-map collisions pure)"
    (phm-collision-test phm/put phm/remove (lambda (m) m)))

  (test-group "(persistent-hash-map collisions mutate)"
    (phm-collision-test phm/put! phm/remove! phm/mutable))

  (test-group "(persistent-hash-map big-hash)"
    "Test that hashes that differ only above `hamt-hash-size' still work."
    (define big-hash
      (let* ((big-1 (expt 2 hamt-hash-size))
	     (big-2 (* 2 big-1)))
	(lambda (string)
	  (cond ((string=? string "foo") big-1)
		(else big-2)))))
    (let* ((alist '(("foo" . 1) ("bar" . 2) ("baz" . 3) ("bat" . 4)
		    ("quux" . 5)))
	   (phm (phm/add-alist (make-phm big-hash string=?) alist)))
      (assert-phm= phm alist)))

  (test-group "(persistent-hash-map same-first-fragment)"
    (define (same-first-fragment string)
      (* hamt-bucket-size (string-hash string)))
    (let* ((alist '(("foo" . 1) ("bar" . 2) ("baz" . 3) ("bat" . 4)
		    ("quux" . 5)))
	   (phm (phm/add-alist (make-phm same-first-fragment string=?) alist)))
      (assert-phm= phm alist)
      (let ((phm-minus-baz (phm/remove phm "baz")))
	(assert-phm= phm-minus-baz (del-assoc "baz" alist)))
      (let ((phm-minus-nonexistent (phm/remove phm "not-present")))
	(test-assert (= (phm/count phm-minus-nonexistent) (length alist))))))

  (test-group "(persistent-hash-map pure-mutate-interference)"
    "Test that mutating and pure operations interact with each other
correctly."
    (define (alist-replace alist key datum)
      (cons (cons key datum) (del-assoc key alist)))
    (let* ((m0 (make-phm string-hash string=?))
	   (a1 '(("foo" . 1) ("bar" . 2) ("baz" . 3)))
	   (m1 (phm/add-alist m0 a1))
	   (a4 (alist-replace a1 "foo" 4))
	   (m2 (phm/put m1 "foo" 4))
	   (a5 (alist-replace a1 "foo" 5))
	   (m3 (phm/mutable m2))
	   (m4 (phm/put! m3 "foo" 5))
	   (a6 (alist-replace a1 "foo" 6))
	   (m5 (phm/immutable m4))
	   (m6 (phm/mutable m5))
	   (m7 (phm/put! m6 "foo" 6))
	   (a7 (alist-replace a1 "foo" 7))
	   (a8 (alist-replace a1 "foo" 8))
	   (m8 (phm/put! m6 "foo" 7)))
      (phm/put! m4 "foo" 8)
      (assert-phm= m0 '())
      (assert-phm= m1 a1)
      (assert-phm= m2 a4)
      (assert-phm= m3 a8)
      (assert-phm= m4 a8)
      (assert-phm= m5 a5)
      (assert-phm= m6 a7)
      (assert-phm= m7 a7)
      (assert-phm= m8 a7)
      (let ((a (del-assoc "foo" a1))
	    (m9 (phm/remove! m4 "foo")))
	(assert-phm= m4 a)
	(assert-phm= m9 a))))

  (test-group "(persistent-hash-map phm/data)"
    (let* ((alist '(("a" . 1) ("b" . 2) ("c" . 3)))
	   (data (phm/data (make-phm string-hash string=? alist))))
      (test-assert (equal? (map cdr alist)
			   (sort data <)))))

  (test-group "(persistent-hash-map phm/keys)"
    (let* ((alist '(("a" . 1) ("b" . 2) ("c" . 3)))
	   (keys (phm/keys (make-phm string-hash string=? alist))))
      (test-assert (equal? (map car alist)
			   (sort keys string<?)))))

  (test-group "(persistent-hash-map phm/for-each)"
    (define (sort-alist alist)
      (sort alist (lambda (a1 a2) (string<? (car a1) (car a2)))))
    (let* ((alist '(("a" . 1) ("b" . 2) ("c" . 3)))
	   (phm (make-phm string-hash string=? alist))
	   (accumulator '()))
      (phm/for-each (lambda (k d) (set! accumulator
				   (cons (cons k d) accumulator)))
		    phm)
      (test-assert (equal? alist (sort-alist accumulator)))))

  (define (persistent-hash-map replace transform)
    (define (sort-alist alist)
      (sort alist (lambda (a1 a2) (string<? (car a1) (car a2)))))
    (let* ((alist-1 '(("a" . 1) ("b" . 2) ("c" . 3)))
	   (alist-2 '(("a" . 1) ("b" . 4) ("c" . 3)))
	   (alist-3 '(("a" . 1) ("b" . 4)))
	   (phm (replace (transform (make-phm string-hash string=? alist-1))
			 "b"
			 (lambda (x) 4))))
      (test-assert (equal? alist-2 (sort-alist (phm->alist phm))))
      (test-assert (equal? alist-3
			   (sort-alist
			    (phm->alist
			     (replace phm "c" (lambda (x) hamt-null))))))))

  (test-group "(persistent-hash-map phm/replace)"
    (persistent-hash-map phm/replace (lambda (m) m)))

  (test-group "(persistent-hash-map phm/replace!)"
    (persistent-hash-map phm/replace! phm/mutable))

  (test-group "(persistent-hash-map immutable-replace)"
    (define (sort-alist alist)
      (sort alist (lambda (a1 a2) (string<? (car a1) (car a2)))))
    (let* ((alist-1 '(("a" . 1) ("b" . 2) ("c" . 3)))
	   (alist-2 '(("a" . 1) ("b" . 5) ("c" . 3)))
	   (phm-1 (phm/mutable (make-phm string-hash string=? alist-1))))
      (phm/put! phm-1 "b" 4)
      (let ((phm-2 (phm/immutable phm-1
				  (lambda (k d) (if (string=? k "b") (1+ d) d)))))
	(test-assert (equal? alist-2 (sort-alist (phm->alist phm-2)))))))

  (test-group "(persistent-hash-map phm/mutable?)"
    (let ((phm (make-phm string-hash string=?)))
      (test-assert (not (phm/mutable? phm)))
      (test-assert (phm/mutable? (phm/mutable phm)))
      (test-assert (not (phm/mutable? (phm/immutable (phm/mutable phm)))))))

  (test-group "(persistent-hash-map modify-collision add-different-hash)"
    (define (terrible-hash string)
      (cond ((string=? string "foo") 0)
	    ((string=? string "bar") 0)
	    (else hamt-bucket-size)))	; same as 0 in bottom 5 bits
    (let* ((alist '(("foo" . 1) ("bar" . 2)))
	   (phm-1 (make-phm terrible-hash string=? alist))
	   (phm-2 (phm/put phm-1 "baz" 3)))
      (assert-phm= phm-2 '(("foo" . 1) ("bar" . 2) ("baz" . 3)))))

  (define (hamt-max-depth hamt)
    "Return maximum depth of `hamt'.  For testing."
    (let descend ((n (hamt/root hamt)))
      (cond ((collision? n) 1)
	    ((narrow? n)
	     (let* ((array (narrow/array n))
		    (stride (leaf-stride (hamt/payload? hamt)))
		    (start (* stride (bit-count (narrow/leaves n))))
		    (end (vector-length array)))
	       (do ((i start (1+ i))
		    (high 0 (max high (descend (vector-ref array i)))))
		   ((= i end) (1+ high)))))
	    ((wide? n)
	     (let ((array (wide/array n))
		   (c (wide/children n)))
	       (let next-child ((high 0)
				(i 0))
		 (cond ((next-set-bit c i hamt-bucket-size)
			=> (lambda (j)
			     (next-child (max high
					      (descend (vector-ref array j)))
					 (1+ j))))
		       (else (1+ high))))))
	    (else (error "Invalid type of node." n)))))

  (test-group "(persistent-hash-map lower-collision)"
    (define same-bottom-three-fragments (expt hamt-bucket-size 3))
    (define (terrible-hash string)
      (if (or (string=? string "foo")
	      (string=? string "bar"))
	  same-bottom-three-fragments
	  (* 2 same-bottom-three-fragments)))
    (let* ((alist '(("foo" . 1) ("bar" . 2)))
	   (phm-1 (make-phm terrible-hash string=? alist))
	   (phm-2 (phm/put phm-1 "baz" 3))
	   (phm-3 (phm/remove phm-2 "foo"))
	   (phm-4 (phm/remove phm-3 "bar"))
	   (phm-5 (phm/remove phm-4 "baz")))
      (assert-phm= phm-2 '(("foo" . 1) ("bar" . 2) ("baz" . 3)))
      (assert-phm= phm-3 '(("bar" . 2) ("baz" . 3)))
      (assert-phm= phm-4 '(("baz" . 3)))
      (assert-phm= phm-5 '())
      (test-assert (= 5 (hamt-max-depth phm-2)))
      (test-assert (= 4 (hamt-max-depth phm-3)))
      (test-assert (= 1 (hamt-max-depth phm-4)))
      (test-assert (= 1 (hamt-max-depth phm-5)))))
  (test-end))