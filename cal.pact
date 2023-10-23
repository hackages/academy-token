;  (namespace "free")

(module repl-academy-cal CAP
    
    (defcap CAP () true)

    (defconst myVar 42)
    
    (defun add (x y)
        (+ x y)
    )
    
    (defun substract (x y)
    (- x y))
    
    (defun add42 (x)
        (let ((myVar 42))
            (format "The value of myVar is [myVar]", myVar))
    ))