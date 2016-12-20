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

(define-library (srfi 146 test)
  (export run-tests)
  (import (scheme base)
	  (srfi 1)
	  (srfi 8)
	  (srfi 64)
	  (srfi 128)
	  (srfi 146))
  (begin
    (define (run-tests)
      (test-begin "SRFI 146")

      (test-group "Predicates"
	(define map0 (make-map comparator))
	(define map1 (make-map comparator 'a 1 'b 2 'c 3))
	(define map2 (make-map comparator 'c 1 'd 2 'e 3))
	(define map3 (make-map comparator 'd 1 'e 2 'f 3))
	
	(test-assert "map?: a map"
	  (map? (make-map comparator)))

	(test-assert "map?: not a map"
	  (not (map? (list 1 2 3))))
	
	(test-assert "map-empty?: empty map"
	  (map-empty? map0))
	
	(test-assert "map-empty?: non-empty map"
	  (not (map-empty? map1)))

	(test-assert "map-contains?: containing"
	  (map-contains? map1 'b))   

	(test-assert "map-contains?: not containing"
	  (not (map-contains? map1 '2)))

	(test-assert "map-disjoint?: disjoint"
	  (map-disjoint? map1 map3))

	(test-assert "map-disjoint?: not disjoint"
	  (not (map-disjoint? map1 map2))))

      (test-group "Accessors"
	(define map1 (make-map comparator 'a 1 'b 2 'c 3))

	(test-equal "map-ref: key found"
	  2
	  (map-ref map1 'b))

	(test-equal "map-ref: key not found/with failure"
	  42
	  (map-ref map1 'd (lambda () 42)))

	(test-error "map-ref: key not found/without failure"
	  (map-ref map1 'd))

	(test-equal "map-ref: with success procedure"
	  (* 2 2)
	  (map-ref map1 'b (lambda () #f) (lambda (x) (* x x))))

	(test-equal "map-ref/default: key found"
	  3
	  (map-ref/default map1 'c 42))

	(test-equal "map-ref/default: key not found"
	  42
	  (map-ref/default map1 'd 42))

	(test-equal "map-key-comparator"
	  comparator
	  (map-key-comparator map1)))

      (test-group "Updaters"
	(define map1 (make-map comparator 'a 1 'b 2 'c 3))
	(define map2 (map-set map1 'c 4 'd 4 'd 5))
	(define map3 (map-update map1 'b (lambda (x) (* x x))))
	(define map4 (map-update/default map1 'd (lambda (x) (* x x)) 4))
	
	(test-equal "map-set: key already in map"
	  3
	  (map-ref map2 'c))

	(test-equal "map-set: key set earlier"
	  4
	  (map-ref map2 'd))

	(test-equal "map-replace: key not in map"
	  #f
	  (map-ref/default (map-replace map1 'd 4) 'd #f))

	(test-equal "map-replace: key in map"
	  6
	  (map-ref (map-replace map1 'c 6) 'c))

	(test-equal "map-delete"
	  42
	  (map-ref/default (map-delete map1 'b) 'b 42))

	(test-equal "map-delete-all"
	  42
	  (map-ref/default (map-delete-all map1 '(a b)) 'b 42))
       
	(test-equal "map-intern: key in map"
	  (list map1 2)
	  (receive result
	      (map-intern map1 'b (lambda () (error "should not have been invoked")))
	    result))

	(test-equal "map-intern: key not in map"
	  (list 42 42)
	  (receive (map value)
	      (map-intern map1 'd (lambda () 42))
	    (list value (map-ref map 'd))))
	    
	(test-equal "map-update"
	  4
	  (map-ref map3 'b))

	(test-equal "map-update/default"
	  16
	  (map-ref map4 'd)))

      (test-group "The whole map"
	(define map0 (make-map comparator))
	(define map1 (make-map comparator 'a 1 'b 2 'c 3))

	(test-equal "map-size: empty map"
	  0
	  (map-size map0))

	(test-equal "map-size: non-empty map"
	  3
	  (map-size map1))

	(test-equal "map-find: found in map"
	  (list 'b 2)
	  (receive result
	      (map-find (lambda (key value)
			  (and (eq? key 'b)
			       (= value 2)))
			map1
			(lambda () (error "should not have been called")))
	    result))

	(test-equal "map-find: not found in map"
	  (list 42)
	  (receive result
	      (map-find (lambda (key value)
			  (eq? key 'd))
			map1
			(lambda ()
			  42))
	    result))

	(test-equal "map-count"
	  2
	  (map-count (lambda (key value)
		       (>= value 2))
		     map1))
      
	(test-assert "map-any?: found"
	  (map-any? (lambda (key value)
		      (= value 3))
		    map1))

	(test-assert "map-any?: not found"
	  (not (map-any? (lambda (key value)
			   (= value 4))
			 map1)))

	(test-assert "map-every?: true"
	  (map-every? (lambda (key value)
			(<= value 3))
		      map1))

	(test-assert "map-every?: false"
	  (not (map-every? (lambda (key value)
			     (<= value 2))
			   map1)))

	(test-equal "map-keys"
	  3
	  (length (map-keys map1)))

	(test-equal "map-values"
	  6
	  (fold + 0 (map-values map1)))

	(test-equal "map-entries"
	  (list 3 6)
	  (receive (keys values)
	      (map-entries map1)
	    (list (length keys) (fold + 0 values)))))

      (test-group "Mapping and folding"
	(define map1 (make-map comparator 'a 1 'b 2 'c 3))
	(define map2 (map-map (lambda (key value)
				(values (symbol->string key)
					(* 10 value)))
			      comparator
			      map1))

	(test-equal "map-map"
	  20
	  (map-ref map2 "b"))

	(test-equal "map-for-each"
	  6
	  (let ((counter 0))
	    (map-for-each (lambda (key value)
			    (set! counter (+ counter value)))
			  map1)
	    counter))

	(test-equal "map-fold"
	  6
	  (map-fold (lambda (key value acc)
		      (+ value acc))
		    0
		    map1))

	(test-equal "map-map->list"
	  (+ (* 1 1) (* 2 2) (* 3 3))
	  (fold + 0 (map-map->list (lambda (key value)
				     (* value value))
				   map1)))

	(test-equal "map-filter"
	  2
	  (map-size (map-filter (lambda (key value)
				  (<= value 2))
				map1)))

	(test-equal "map-remove"
	  1
	  (map-size (map-remove (lambda (key value)
				  (<= value 2))
				map1)))

	(test-equal "map-partition"
	  (list 1 2)
	  (receive result
	      (map-partition (lambda (key value)
			       (eq? 'b key))
			     map1)
	    (map map-size result)))

	(test-group "Copying and conversion"
	  (define map1 (make-map comparator 'a 1 'b 2 'c 3))
	  (define map2 (alist->map comparator '((a . 1) (b . 2) (c . 3))))
	  (define map3 (alist->map! (map-copy map1) '((d . 4) '(c . 5))))
	  
	  (test-equal "map-copy: same size"
	    3
	    (map-size (map-copy map1)))

	  (test-equal "map-copy: same comparator"
	    comparator
	    (map-key-comparator (map-copy map1)))

	  (test-equal "map->alist"
	    (cons 'b 2)
	    (assq 'b (map->alist map1)))
	  
	  (test-equal "alist->map"
	    2
	    (map-ref map2 'b)
	    )

	  (test-equal "alist->map!: new key"
	    4
	    (map-ref map3 'd))

	  (test-equal "alist->map!: existing key"
	    3
	    (map-ref map3 'c)))

	(test-group "Submaps"
	  (define map1 (make-map comparator 'a 1 'b 2 'c 3))
	  (define map2 (make-map comparator 'a 1 'b 2 'c 3))
	  (define map3 (make-map comparator 'a 1 'c 3))
	  (define map4 (make-map comparator 'a 1 'c 3 'd 4))
	  (define map5 (make-map comparator 'a 1 'b 2 'c 6))

	  (test-assert "map=?: equal maps"
	    (map=? comparator map1 map2))

	  (test-assert "map=?: unequal maps"
	    (not (map=? comparator map1 map4)))

	  (test-assert "map<?: proper subset"
	    (map<? comparator map3 map1))

	  (test-assert "map<?: improper subset"
	    (not (map<? comparator map3 map1 map2)))
	  
	  (test-assert "map>?: proper superset"
	    (map>? comparator map2 map3))

	  (test-assert "map>?: improper superset"
	    (not (map>? comparator map1 map2 map3)))

	  (test-assert "map<=?: subset"
	    (map<=? comparator map3 map2 map1))

	  (test-assert "map<=?: non-matching values"
	    (not (map<=? comparator map3 map5)))

	  (test-assert "map<=?: not a subset"
	    (not (map<=? comparator map2 map4)))

	  (test-assert "map>=?: superset"
	    (map>=? comparator map4 map3))

	  (test-assert "map>=?: not a superset"
	    (not (map>=? comparator map5 map3))))

	(test-group "Set theory operations"
	  (define map1 (make-map comparator 'a 1 'b 2 'c 3))
	  (define map2 (make-map comparator 'a 1 'b 2 'd 4))
	  (define map3 (make-map comparator 'a 1 'b 2))
	  (define map4 (make-map comparator 'a 1 'b 2 'c 4))
	  (define map5 (make-map comparator 'a 1 'c 3))
	  (define map6 (make-map comparator 'd 4 'e 5 'f 6))
	  
	  (test-equal "map-union: new association"
	    4
	    (map-ref (map-union map1 map2) 'd))

	  (test-equal "map-union: existing association"
	    3
	    (map-ref (map-union map1 map4) 'c))
	  
	  (test-equal "map-union: three maps"
	    6
	    (map-size (map-union map1 map2 map6)))
	  
	  (test-equal "map-intersection: existing association"
	    3
	    (map-ref (map-intersection map1 map4) 'c))

	  (test-equal "map-intersection: removed association"
	    42
	    (map-ref/default (map-intersection map1 map5) 'b 42))

	  (test-equal "map-difference"
	    2
	    (map-size (map-difference map2 map6)))

	  (test-equal "map-xor"
	    4
	    (map-size (map-xor map2 map6))))
	
	(test-group "Comparators"
	  (define map1 (make-map comparator 'a 1 'b 2 'c 3))
	  (define map2 (make-map comparator 'a 1 'b 2 'c 3))
	  (define map3 (make-map comparator 'a 1 'b 2))
	  (define map4 (make-map comparator 'a 1 'b 2 'c 4))
	  (define map5 (make-map comparator 'a 1 'c 3))
	  (define map0 (make-map comparator map1 "a" map2 "b" map3 "c" map4 "d" map5 "e"))

	  (test-assert "map-comparator"
	    (comparator? map-comparator))
	  
	  (test-equal "map-keyed map"
	    (list "a" "a" "c" "d" "e")
	    (list (map-ref map0 map1)
		  (map-ref map0 map2)
		  (map-ref map0 map3)
		  (map-ref map0 map4)
		  (map-ref map0 map5)))
	  
	  (test-group "Ordering comparators"
	    (test-assert "=?: equal maps"
	      (=? comparator map1 map2))

	    (test-assert "=?: unequal maps"
	      (not (=? comparator map1 map4)))

	    (test-assert "<?: case 1"
	      (<? comparator map3 map4))

	    (test-assert "<?: case 2"
	      (<? comparator map1 map4))

	    (test-assert "<?: case 3"
	      (<? comparator map1 map5)))))

      
      
      (test-end "SRFI 146"))

    (define comparator (make-default-comparator))))
