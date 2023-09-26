(module math-calculator ADMIN

    (defcap ADMIN () true)

    (defun add (a:integer b:integer)
        @doc "Adds two integers"
        (+ a b)) 
    
    (defun substract (a:integer b:integer)
        @doc "Substracts two integers"
        (- a b))
    
    (defun multiply (a:integer b:integer)
        @doc "Multiplies two integers"
        (* a b))
    
    (defun sum (nums: [integer])
        @doc "Add multiple numbers of integers"
        (fold  (+) 0 nums))
    
    (defun mult (nums: [integer])
        @doc "Multiply multiple numbers of integers"
        (fold  (*) 1 nums))
)