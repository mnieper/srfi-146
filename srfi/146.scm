;; Copyright (C) Marc Nieper-Wißkirchen (2016).  All Rights Reserved. 

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
;; NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
;; BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
;; ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
;; CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;; SOFTWARE.

;;; New types

(define-record-type <mapping>
  (%make-mapping comparator tree)
  mapping?
  (comparator mapping-key-comparator)
  (tree mapping-tree))

(define (make-empty-mapping comparator)
  (assume-type comparator? comparator)
  (%make-mapping comparator (make-tree)))

;;; Exported procedures

;; Constructors

(define (mapping comparator . args)
  (assume-type comparator? comparator)
  (mapping-unfold null?
	      (lambda (args)
		(values (car args)
			(cadr args)))
	      cddr
	      args
	      comparator))

(define (mapping-unfold stop? mapper successor seed comparator)
  (assume-type procedure? stop?)
  (assume-type procedure? mapper)
  (assume-type procedure? successor)
  (assume-type comparator? comparator)
  (let loop ((mapping (make-empty-mapping comparator))
	     (seed seed))
    (if (stop? seed)
	mapping
	(receive (key value)
	    (mapper seed)
	  (loop (mapping-set mapping key value)
		(successor seed))))))

;; Predicates

(define (mapping-empty? mapping)
  (assume-type mapping? mapping)
  (not (mapping-any? (lambda (key value) #t) mapping)))

(define (mapping-contains? mapping key)
  (assume-type mapping? mapping)
  (call/cc
   (lambda (return)
     (mapping-search mapping
		 key
		 (lambda (insert ignore)
		   (return #f))
		 (lambda (key value update remove)
		   (return #t))))))

(define (mapping-disjoint? mapping1 mapping2)
  (assume-type mapping? mapping1)
  (assume-type mapping? mapping2)
  (call/cc
   (lambda (return)
     (mapping-for-each (lambda (key value)
		     (when (mapping-contains? mapping2 key)
		       (return #f)))
		   mapping1)
     #t)))

;; Accessors

(define mapping-ref
  (case-lambda
    ((mapping key)
     (assume-type mapping? mapping)
     (mapping-ref mapping key (lambda ()
			(fatal-error "mapping-ref: key not in mapping" key))))
    ((mapping key failure)
     (assume-type mapping? mapping)
     (assume-type procedure? failure)
     (mapping-ref mapping key failure (lambda (value)
				value)))
    ((mapping key failure success)
     (assume-type mapping? mapping)
     (assume-type procedure? failure)
     (assume-type procedure? success)
     (call/cc
      (lambda (return)
	(mapping-search mapping
		    key
		    (lambda (insert ignore)
		      (return (failure)))
		    (lambda (key value update remove)
		      (return (success value)))))))))

(define (mapping-ref/default mapping key default)
  (assume-type mapping? mapping)
  (mapping-ref mapping key (lambda () default)))

;; Updaters

(define (mapping-set mapping . args)
  (assume-type mapping? mapping)
  (let loop ((args args)
	     (mapping mapping))
    (if (null? args)
	mapping
	(receive (mapping)
	    (mapping-update mapping (car args) (lambda (value) (cadr args)) (lambda () #f))	
	  (loop (cddr args)
		mapping)))))

(define mapping-set! mapping-set)

(define (mapping-replace mapping key value)
  (assume-type mapping? mapping)
  (receive (mapping obj)
      (mapping-search mapping
		  key
		  (lambda (insert ignore)
		    (ignore #f))
		  (lambda (old-key old-value update remove)
		    (update key value #f)))
    mapping))

(define mapping-replace! mapping-replace)

(define (mapping-delete mapping . keys)
  (assume-type mapping? mapping)
  (mapping-delete-all mapping keys))

(define mapping-delete! mapping-delete)

(define (mapping-delete-all mapping keys)
  (assume-type mapping? mapping)
  (assume-type list? keys)
  (fold (lambda (key mapping)
	  (receive (mapping obj)
	      (mapping-search mapping
			  key
			  (lambda (insert ignore)
			    (ignore #f))
			  (lambda (old-key old-value update remove)
			    (remove #f)))
	    mapping))
	mapping keys))

(define mapping-delete-all! mapping-delete-all)

(define (mapping-intern mapping key failure)
  (assume-type mapping? mapping)
  (assume-type procedure? failure)
  (call/cc
   (lambda (return)
     (mapping-search mapping
		 key
		 (lambda (insert ignore)
		   (receive (value)
		       (failure)
		     (insert key value value)))
		 (lambda (old-key old-value update remove)
		   (return mapping old-value))))))

(define mapping-intern! mapping-intern)

(define mapping-update 
  (case-lambda
   ((mapping key updater)
    (mapping-update mapping key updater (lambda ()
				  (fatal-error "mapping-update: key not found in mapping" key))))
   ((mapping key updater failure)
    (mapping-update mapping key updater failure (lambda (value)
					  value)))
   ((mapping key updater failure success)
    (assume-type mapping? mapping)
    (assume-type procedure? updater)
    (assume-type procedure? failure)
    (assume-type procedure? success)
    (receive (mapping obj)
	(mapping-search mapping
		    key
		    (lambda (insert ignore)
		      (insert key (updater (failure)) #f))
		    (lambda (old-key old-value update remove)
		      (update key (updater (success old-value)) #f)))
      mapping))))

(define mapping-update! mapping-update)

(define (mapping-update/default mapping key updater default)
  (mapping-update mapping key updater (lambda () default)))

(define mapping-update!/default mapping-update/default)

(define (mapping-search mapping key failure success)
  (assume-type mapping? mapping)
  (assume-type procedure? failure)
  (assume-type procedure? success)
  (call/cc
   (lambda (return)
     (let*-values
	 (((comparator)
	   (mapping-key-comparator mapping))
	  ((tree obj)
	   (tree-search comparator
			(mapping-tree mapping)
			key
			(lambda (insert ignore)
			  (failure insert
				   (lambda (obj)
				     (return mapping obj))))
			success)))
       (values (%make-mapping comparator tree)
	       obj)))))

(define mapping-search! mapping-search)

;; The whole mapping

(define (mapping-size mapping)
  (assume-type mapping? mapping)
  (mapping-count (lambda (key value)
	       #t)
	     mapping))

(define (mapping-find predicate mapping failure)
  (assume-type procedure? predicate)
  (assume-type mapping? mapping)
  (assume-type procedure? failure)
  (call/cc
   (lambda (return)
     (mapping-for-each (lambda (key value)
		     (when (predicate key value)
		       (return key value)))
		   mapping)
     (failure))))

(define (mapping-count predicate mapping)
  (assume-type procedure? predicate)
  (assume-type mapping? mapping)
  (mapping-fold (lambda (key value count)
	      (if (predicate key value)
		  (+ 1 count)
		  count))
	    0 mapping))

(define (mapping-any? predicate mapping)
  (assume-type procedure? predicate)
  (assume-type mapping? mapping)
  (call/cc
   (lambda (return)
     (mapping-for-each (lambda (key value)
		     (when (predicate key value)
		       (return #t)))
		   mapping)
     #f)))

(define (mapping-every? predicate mapping)
  (assume-type procedure? predicate)
  (assume-type mapping? mapping)
  (not (mapping-any? (lambda (key value)
		   (not (predicate key value)))
		 mapping)))

(define (mapping-keys mapping)
  (assume-type mapping? mapping)
  (reverse
   (mapping-fold (lambda (key value keys)
		   (cons key keys))
		 '() mapping)))

(define (mapping-values mapping)
  (assume-type mapping? mapping)
  (reverse
   (mapping-fold (lambda (key value values)
		   (cons value values))
		 '() mapping)))

(define (mapping-entries mapping)
  (assume-type mapping? mapping)
  (values (mapping-keys mapping)
	  (mapping-values mapping)))

;; Mapping and folding

(define (mapping-map proc comparator mapping)
  (assume-type procedure? proc)
  (assume-type comparator? comparator)
  (assume-type mapping? mapping)
  (mapping-fold (lambda (key value mapping)
	      (receive (key value)
		  (proc key value)
		(mapping-set mapping key value)))
	    (make-empty-mapping comparator)
	    mapping))

(define (mapping-for-each proc mapping)
  (assume-type procedure? proc)
  (assume-type mapping? mapping)
  (tree-for-each proc (mapping-tree mapping)))

(define (mapping-fold proc acc mapping)
  (assume-type procedure? proc)
  (assume-type mapping? mapping)
  (tree-fold proc acc (mapping-tree mapping)))

(define (mapping-map->list proc mapping)
  (assume-type procedure? proc)
  (assume-type mapping? mapping)
  (reverse
   (mapping-fold (lambda (key value lst)
		   (cons (proc key value) lst))
		 '()
		 mapping)))

(define (mapping-filter predicate mapping)
  (assume-type procedure? predicate)
  (assume-type mapping? mapping)
  (mapping-fold (lambda (key value mapping)
	      (if (predicate key value)
		  (mapping-set mapping key value)
		  mapping))
	    (make-empty-mapping (mapping-key-comparator mapping))
	    mapping))

(define mapping-filter! mapping-filter)

(define (mapping-remove predicate mapping)
  (assume-type procedure? predicate)
  (assume-type mapping? mapping)
  (mapping-filter (lambda (key value)
		(not (predicate key value)))
	      mapping))

(define mapping-remove! mapping-remove)

(define (mapping-partition predicate mapping)
  (assume-type procedure? predicate)
  (assume-type mapping? mapping)
  (values (mapping-filter predicate mapping)
	  (mapping-remove predicate mapping)))

(define mapping-partition! mapping-partition)

;; Copying and conversion

(define (mapping-copy mapping)
  (assume-type mapping? mapping)
  mapping)

(define (mapping->alist mapping)
  (assume-type mapping? mapping)
  (reverse
   (mapping-fold (lambda (key value alist)
		   (cons (cons key value) alist))
		 '() mapping)))

(define (alist->mapping comparator alist)
  (assume-type comparator? comparator)
  (assume-type list? alist)
  (mapping-unfold null?
	      (lambda (alist)
		(let ((key (caar alist))
		      (value (cdar alist)))
		  (values key value)))
	      cdr
	      alist
	      comparator))

(define (alist->mapping! mapping alist)
  (assume-type mapping? mapping)
  (assume-type list? alist)
  (fold (lambda (association mapping)
	  (let ((key (car association))
		(value (cdr association)))
	    (mapping-set mapping key value)))
	mapping
	alist))

;; Submappings

(define mapping=?
  (case-lambda
    ((comparator mapping)
     (assume-type mapping? mapping)
     #t)
    ((comparator mapping1 mapping2) (%mapping=? comparator mapping1 mapping2))
    ((comparator mapping1 mapping2 . mappings)
     (and (%mapping=? comparator mapping1 mapping2)
          (apply mapping=? comparator mapping2 mappings)))))
(define (%mapping=? comparator mapping1 mapping2)
  (and (%mapping<=? comparator mapping1 mapping2)
       (%mapping<=? comparator mapping2 mapping1)))

(define mapping<=?
  (case-lambda
    ((comparator mapping)
     (assume-type mapping? mapping)
     #t)
    ((comparator mapping1 mapping2)
     (assume-type comparator? comparator)
     (assume-type mapping? mapping1)
     (assume-type mapping? mapping2)
     (%mapping<=? comparator mapping1 mapping2))
    ((comparator mapping1 mapping2 . mappings)
     (assume-type comparator? comparator)
     (assume-type mapping? mapping1)
     (assume-type mapping? mapping2)
     (and (%mapping<=? comparator mapping1 mapping2)
          (apply mapping<=? comparator mapping2 mappings)))))

(define (%mapping<=? comparator mapping1 mapping2)
  (assume-type comparator? comparator)
  (assume-type mapping? mapping1)
  (assume-type mapping? mapping2)
  (let ((less? (comparator-ordering-predicate (mapping-key-comparator mapping1)))
	(equality-predicate (comparator-equality-predicate comparator))
	(gen1 (tree-generator (mapping-tree mapping1)))
	(gen2 (tree-generator (mapping-tree mapping2))))    
    (let loop ((item1 (gen1))
	       (item2 (gen2)))
      (cond
       ((eof-object? item1)
	#t)
       ((eof-object? item2)
	#f)
       (else
	(let ((key1 (car item1)) (value1 (cadr item1))
	      (key2 (car item2)) (value2 (cadr item2)))
	  (cond
	   ((less? key1 key2)
	    #f)
	   ((less? key2 key1)
	    (loop item1 (gen2)))
	   ((equality-predicate item1 item2)
	    (loop (gen1) (gen2)))
	   (else
	    #f))))))))

(define mapping>?
  (case-lambda
    ((comparator mapping)
     (assume-type mapping? mapping)
     #t)
    ((comparator mapping1 mapping2)
     (assume-type comparator? comparator)
     (assume-type mapping? mapping1)
     (assume-type mapping? mapping2)
     (%mapping>? comparator mapping1 mapping2))
    ((comparator mapping1 mapping2 . mappings)
     (assume-type comparator? comparator)
     (assume-type mapping? mapping1)
     (assume-type mapping? mapping2)
     (and (%mapping>? comparator  mapping1 mapping2)
          (apply mapping>? comparator mapping2 mappings)))))

(define (%mapping>? comparator mapping1 mapping2)
  (assume-type comparator? comparator)
  (assume-type mapping? mapping1)
  (assume-type mapping? mapping2)
  (not (%mapping<=? comparator mapping1 mapping2)))

(define mapping<?
  (case-lambda
    ((comparator mapping)
     (assume-type mapping? mapping)
     #t)
    ((comparator mapping1 mapping2)
     (assume-type comparator? comparator)
     (assume-type mapping? mapping1)
     (assume-type mapping? mapping2)
     (%mapping<? comparator mapping1 mapping2))
    ((comparator mapping1 mapping2 . mappings)
     (assume-type comparator? comparator)
     (assume-type mapping? mapping1)
     (assume-type mapping? mapping2)
     (and (%mapping<? comparator  mapping1 mapping2)
          (apply mapping<? comparator mapping2 mappings)))))

(define (%mapping<? comparator mapping1 mapping2)
     (assume-type comparator? comparator)
     (assume-type mapping? mapping1)
     (assume-type mapping? mapping2)
     (%mapping>? comparator mapping2 mapping1))

(define mapping>=?
  (case-lambda
    ((comparator mapping)
     (assume-type mapping? mapping)
     #t)
    ((comparator mapping1 mapping2)
     (assume-type comparator? comparator)
     (assume-type mapping? mapping1)
     (assume-type mapping? mapping2)
     (%mapping>=? comparator mapping1 mapping2))
    ((comparator mapping1 mapping2 . mappings)
     (assume-type comparator? comparator)
     (assume-type mapping? mapping1)
     (assume-type mapping? mapping2)
     (and (%mapping>=? comparator mapping1 mapping2)
          (apply mapping>=? comparator mapping2 mappings)))))

(define (%mapping>=? comparator mapping1 mapping2)
  (assume-type comparator? comparator)
  (assume-type mapping? mapping1)
  (assume-type mapping? mapping2)
  (not (%mapping<? comparator mapping1 mapping2)))

;; Set theory operations

(define (%mapping-union mapping1 mapping2)
  (mapping-fold (lambda (key2 value2 mapping)
	      (receive (mapping obj)
		  (mapping-search mapping
			      key2
			      (lambda (insert ignore)
				(insert key2 value2 #f))
			      (lambda (key1 value1 update remove)
				(update key1 value1 #f)))
		mapping))
	    mapping1 mapping2))

(define (%mapping-intersection mapping1 mapping2)
  (mapping-filter (lambda (key1 value1)
		(mapping-contains? mapping2 key1))
	      mapping1))

(define (%mapping-difference mapping1 mapping2)
  (mapping-fold (lambda (key2 value2 mapping)
	      (receive (mapping obj)
		  (mapping-search mapping
			      key2
			      (lambda (insert ignore)
				(ignore #f))
			      (lambda (key1 value1 update remove)
				(remove #f)))
		mapping))
	    mapping1 mapping2))

(define (%mapping-xor mapping1 mapping2)
  (mapping-fold (lambda (key2 value2 mapping)
	      (receive (mapping obj)
		  (mapping-search mapping
			      key2
			      (lambda (insert ignore)
				(insert key2 value2 #f))
			      (lambda (key1 value1 update remove)
				(remove #f)))
		mapping))
	    mapping1 mapping2))

(define mapping-union
  (case-lambda
    ((mapping)
     (assume-type mapping? mapping)
     mapping)
    ((mapping1 mapping2)
     (assume-type mapping? mapping1)
     (assume-type mapping? mapping2)
     (%mapping-union mapping1 mapping2))
    ((mapping1 mapping2 . mappings)
     (assume-type mapping? mapping1)
     (assume-type mapping? mapping2)
     (apply mapping-union (%mapping-union mapping1 mapping2) mappings))))
(define mapping-union! mapping-union)

(define mapping-intersection
  (case-lambda
    ((mapping)
     (assume-type mapping? mapping)
     mapping)
    ((mapping1 mapping2)
     (assume-type mapping? mapping1)
     (assume-type mapping? mapping2)
     (%mapping-intersection mapping1 mapping2))
    ((mapping1 mapping2 . mappings)
     (assume-type mapping? mapping1)
     (assume-type mapping? mapping2)
     (apply mapping-intersection (%mapping-intersection mapping1 mapping2) mappings))))
(define mapping-intersection! mapping-intersection)

(define mapping-difference
  (case-lambda
    ((mapping)
     (assume-type mapping? mapping)
     mapping)
    ((mapping1 mapping2)
     (assume-type mapping? mapping1)
     (assume-type mapping? mapping2)
     (%mapping-difference mapping1 mapping2))
    ((mapping1 mapping2 . mappings)
     (assume-type mapping? mapping1)
     (assume-type mapping? mapping2)
     (apply mapping-difference (%mapping-difference mapping1 mapping2) mappings))))
(define mapping-difference! mapping-difference)

(define mapping-xor
  (case-lambda
    ((mapping)
     (assume-type mapping? mapping)
     mapping)
    ((mapping1 mapping2)
     (assume-type mapping? mapping1)
     (assume-type mapping? mapping2)
     (%mapping-xor mapping1 mapping2))
    ((mapping1 mapping2 . mappings)
     (assume-type mapping? mapping1)
     (assume-type mapping? mapping2)
     (apply mapping-xor (%mapping-xor mapping1 mapping2) mappings))))
(define mapping-xor! mapping-xor)

;; Comparators

(define (mapping-equality comparator)
  (assume-type comparator? comparator)
  (lambda (mapping1 mapping2)
    (mapping=? comparator mapping1 mapping2)))

(define (mapping-ordering comparator)
  (assume-type comparator? comparator)
  (let ((value-equality (comparator-equality-predicate comparator))
	(value-ordering (comparator-ordering-predicate comparator)))
    (lambda (mapping1 mapping2)
      (let* ((key-comparator (mapping-key-comparator mapping1))
	     (equality (comparator-equality-predicate key-comparator))
	     (ordering (comparator-ordering-predicate key-comparator))
	     (gen1 (tree-generator (mapping-tree mapping1)))
	     (gen2 (tree-generator (mapping-tree mapping2))))
	(let loop ()
	  (let ((item1 (gen1)) (item2 (gen2)))
	    (cond
	     ((eof-object? item1)
	      (not (eof-object? item2)))
	     ((eof-object? item2)
	      #f)
	     (else
	      (let ((key1 (car item1)) (value1 (cadr item1))
		    (key2 (car item2)) (value2 (cadr item2)))
		(cond
		 ((equality key1 key2)
		  (if (value-equality value1 value2)
		      (loop)
		      (value-ordering value1 value2)))
		 (else
		  (ordering key1 key2))))))))))))

(define (make-mapping-comparator comparator)
  (make-comparator mapping? (mapping-equality comparator) (mapping-ordering comparator) #f))

(define mapping-comparator (make-mapping-comparator (make-default-comparator)))

(comparator-register-default! mapping-comparator)