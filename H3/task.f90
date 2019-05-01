module Task
use mpi
implicit none

contains

     subroutine GetMaxCoordinates(A, x1, y1, x2, y2)
     implicit none
        
     real(8), dimension(:,:), intent(in) :: A
     integer(4), intent(out) :: x1, y1, x2, y2
     integer(4) :: n, L, R, Up, Down, m, tmp
     real(8), allocatable :: current_column(:), B(:,:)
     real(8) :: current_sum
     logical :: transpos
     real(8) :: max_sum   
        
     ! Вспомогательные переменные MPI
     integer(4) mpiErr, mpiSize, mpiRank
     integer(4) ierr, status
     
     ! Переменные для деления первого подпространства итераций на порции
     integer(4) L_partion_size
     integer(4) L_partion_size_mod
     integer(4) L_LB, L_RB ! Границы индексов для данного ранга
     
     ! Переменные для определения результата
     real(8) real_max_sum(2)
     integer max_index
     
     
          m = size(A, dim=1) 
          n = size(A, dim=2) 
          transpos = .FALSE.

          if (m < n) then 
               transpos = .TRUE.   
               B = transpose(A)
               m = size(B, dim=1) 
               n = size(B, dim=2) 
          else
                B = A     
          endif

               call mpi_comm_size(MPI_COMM_WORLD, mpiSize, mpiErr)
               call mpi_comm_rank(MPI_COMM_WORLD, mpiRank, mpiErr)

          allocate(current_column(m))

               max_sum = B(1,1)
               x1 = 1
               y1 = 1
               x2 = 1
               y2 = 1

                    ! Вычисление размера порции
                    L_partion_size_mod = mod(n,mpiSize)
               
                    if (L_partion_size_mod .eq. 0) then
               
                         L_partion_size = n / mpiSize
               
                    else
               
                         L_partion_size = (n + (mpiSize - L_partion_size_mod)) / mpiSize
          
                    endif
                 
               ! Работа процесса над своей порцией   
               L_LB = 1 + mpiRank * L_partion_size
               L_RB = L_partion_size + mpiRank * L_partion_size

          do L = L_LB, L_RB    
          
          if (L .gt. n) cycle    

               current_column = B(:, L)
               do R = L, n
 
                    if (R > L) then 
                         current_column = current_column + B(:, R)
                    endif
                
                    call FindMaxInArray(current_column, current_sum, Up, Down) 
                      
                    if (current_sum > max_sum) then
                         max_sum = current_sum
                         x1 = Up
                         x2 = Down
                         y1 = L
                         y2 = R
                    
                    endif
               end do
          end do
        
     deallocate(current_column)
       
     ! Определение ранга процесса с максимальным значением max_sum
     call mpi_reduce(max_sum, real_max_sum, 4, MPI_2DOUBLE_PRECISION, MPI_MAXLOC, 0, MPI_COMM_WORLD, ierr)
     
     ! Сообщение другим процессам результатов
     
     max_index = int(real_max_sum(2))
     
     call mpi_bcast(x1, 1, MPI_DOUBLE_PRECISION, max_index, MPI_COMM_WORLD, ierr)
     call mpi_bcast(y1, 1, MPI_DOUBLE_PRECISION, max_index, MPI_COMM_WORLD, ierr)
     call mpi_bcast(x2, 1, MPI_DOUBLE_PRECISION, max_index, MPI_COMM_WORLD, ierr)
     call mpi_bcast(y2, 1, MPI_DOUBLE_PRECISION, max_index, MPI_COMM_WORLD, ierr)
                                                                       
                                                                       
        if (transpos) then  
            tmp = x1
            x1 = y1
            y1 = tmp
    
            tmp = y2
            y2 = x2
            x2 = tmp
            endif

       end subroutine


        subroutine FindMaxInArray(a, ans, Up, Down)
        implicit none
        
            real(8), intent(in), dimension(:) :: a
            integer(4), intent(out) :: Up, Down
            real(8), intent(out) :: ans
            real(8) :: cur, sum, min_sum
            integer(4) :: min_pos, i

            ans = a(1)
            Up = 1
            Down = 1
            sum = 0d0
            min_sum = 0d0
            min_pos = 0

            do i=1, size(a)
                sum = sum + a(i)
                cur = sum - min_sum
            if (cur > ans) then
                ans = cur
                Up = min_pos + 1
                Down = i
                endif
         
            if (sum < min_sum) then
                min_sum = sum
                min_pos = i
                endif

            enddo

        end subroutine FindMaxInArray


end module
