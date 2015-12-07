module mg_relax

  use mg_mpi
  use mg_tictoc
  use mg_namelist
  use mg_grids
  use mg_define_matrix

  implicit none

contains

  !----------------------------------------
  subroutine relax(lev,nsweeps)
    integer(kind=ip), intent(in):: lev
    integer(kind=ip), intent(in):: nsweeps

    real(kind=rp),dimension(:,:,:), pointer:: p
    real(kind=rp),dimension(:,:,:), pointer:: b
    real(kind=rp),dimension(:,:,:,:), pointer:: cA

    integer(kind=ip) :: nx, ny, nz, nh

    p  => grid(lev)%p
    b  => grid(lev)%b
    cA => grid(lev)%cA

    nx = grid(lev)%nx
    ny = grid(lev)%ny
    nz = grid(lev)%nz
    nh = grid(lev)%nh

    if (grid(lev)%nz == 1) then
       call relax_2D(lev,p,b,cA,nsweeps,nx,ny)
    else
       !- We can add additional 3D relax routines
       !- creteria: based on grid aspect ratio
       call relax_3D_line(lev,p,b,cA,nsweeps,nx,ny,nz)
    end if

  end subroutine relax

  !----------------------------------------
  subroutine relax_2D(lev,p,b,cA,nsweeps,nx,ny)
    integer(kind=ip)                        , intent(in)   :: lev
    real(kind=rp),dimension(:,:,:)  , pointer, intent(inout):: p
    real(kind=rp),dimension(:,:,:)  , pointer, intent(in)   :: b
    real(kind=rp),dimension(:,:,:,:), pointer, intent(in)   :: cA
    integer(kind=ip)                        , intent(in)   :: nsweeps
    integer(kind=ip)                        , intent(in)   :: nx, ny

    integer(kind=ip)           :: i,j,k, it

    k=1

    do it = 1,nsweeps
       do i = 1,nx
          do j = 1,ny
             p(k,j,i) = b(k,j,i)                                           &
                  - cA(2,k,j,i)*p(k  ,j-1,i) - cA(2,k  ,j+1,i)*p(k  ,j+1,i)&
                  - cA(3,k,j,i)*p(k  ,j,i-1) - cA(3,k  ,j,i+1)*p(k  ,j,i+1)
             p(k,j,i) = p(k,j,i) / cA(1,k,j,i)
          enddo
       enddo
    enddo

    call fill_halo(lev,p)

  end subroutine relax_2D
  
  !----------------------------------------
  subroutine relax_3D_line(lev,p,b,cA,nsweeps,nx,ny,nz)
    integer(kind=ip)                        , intent(in)   :: lev
    real(kind=rp),dimension(:,:,:)  , pointer, intent(inout):: p
    real(kind=rp),dimension(:,:,:)  , pointer, intent(in)   :: b
    real(kind=rp),dimension(:,:,:,:), pointer, intent(in)   :: cA
    integer(kind=ip)                        , intent(in)   :: nsweeps
    integer(kind=ip)                        , intent(in)   :: nx, ny, nz

    ! Coefficients are stored in order of diagonals
    ! cA(1,:,:,:)      -> p(k,j,i)
    ! cA(2,:,:,:)      -> p(k-1,j,i)
    ! cA(3,:,:,:)      -> p(k+1,j-1,i)
    ! cA(4,:,:,:)      -> p(k,j-1,i)
    ! cA(5,:,:,:)      -> p(k-1,j-1,i)
    ! cA(6,:,:,:)      -> p(k+1,j,i-1)
    ! cA(7,:,:,:)      -> p(k,j,i-1)
    ! cA(8,:,:,:)      -> p(k-1,j,i-1)
    !
    !     LOCAL 
    integer(kind=ip)           :: i,j,k,it
    real(kind=rp),dimension(nz) :: rhs,d,ud,p1d

    call tic(lev,'relax_line')

    !--DEBUG !!!!
    call fill_halo(lev,p)
    !--DEBUG !!!!

    !
    ! add a loop on smoothing
    do it = 1,nsweeps

       do i = 1,nx
          !           do i = 1 + mod(j+red_black,2),nx, 2
          do j = 1,ny

             k=1!lower level
             rhs(k) = b(k,j,i)                                              &
                  - cA(3,k,j,i)*p(k+1,j-1,i)                                &
                  - cA(4,k,j,i)*p(k  ,j-1,i) - cA(4,k  ,j+1,i)*p(k  ,j+1,i) &
                                             - cA(5,k+1,j+1,i)*p(k+1,j+1,i) &
                  - cA(6,k,j,i)*p(k+1,j,i-1)                                &
                  - cA(7,k,j,i)*p(k  ,j,i-1) - cA(7,k  ,j,i+1)*p(k  ,j,i+1) &
                                             - cA(8,k+1,j,i+1)*p(k+1,j,i+1)
             d(k)   = cA(1,k,j,i)
             ud(k)  = cA(2,k+1,j,i)

             do k = 2,nz-1!interior levels
                rhs(k) = b(k,j,i) &
                     - cA(3,k,j,i)*p(k+1,j-1,i) - cA(3,k-1,j+1,i)*p(k-1,j+1,i) &
                     - cA(4,k,j,i)*p(k  ,j-1,i) - cA(4,k  ,j+1,i)*p(k  ,j+1,i) &
                     - cA(5,k,j,i)*p(k-1,j-1,i) - cA(5,k+1,j+1,i)*p(k+1,j+1,i) &
                     - cA(6,k,j,i)*p(k+1,j,i-1) - cA(6,k-1,j,i+1)*p(k-1,j,i+1) &
                     - cA(7,k,j,i)*p(k  ,j,i-1) - cA(7,k  ,j,i+1)*p(k  ,j,i+1) &
                     - cA(8,k,j,i)*p(k-1,j,i-1) - cA(8,k+1,j,i+1)*p(k+1,j,i+1)
                d(k)   = cA(1,k,j,i)
                ud(k)  = cA(2,k+1,j,i)
             enddo

             k=nz!upper level
             rhs(k) = b(k,j,i)                                              &
                                             - cA(3,k-1,j+1,i)*p(k-1,j+1,i) &
                  - cA(4,k,j,i)*p(k  ,j-1,i) - cA(4,k  ,j+1,i)*p(k  ,j+1,i) &
                  - cA(5,k,j,i)*p(k-1,j-1,i)                                &
                                             - cA(6,k-1,j,i+1)*p(k-1,j,i+1) &
                  - cA(7,k,j,i)*p(k  ,j,i-1) - cA(7,k  ,j,i+1)*p(k  ,j,i+1) &
                  - cA(8,k,j,i)*p(k-1,j,i-1) 
             d(k)   = cA(1,k,j,i)

             call tic(lev,'tridiag')
             call tridiag(nz,d,ud,rhs,p1d) !solve for vertical_coeff_matrix.p1d=rhs
             call toc(lev,'tridiag')

             do k = 1,nz
                p(k,j,i) = p1d(k)
             enddo

          enddo
       enddo
    enddo

    ! don't call mpi at every pass if nh>1
    call fill_halo(lev,p)

    call toc(lev,'relax_line')

  end subroutine relax_3D_line

  !----------------------------------------
  subroutine tridiag(l,d,dd,b,xc)
    !     Axc = b
    !     Solve tridiagonal system
    implicit none
    !     IMPORT/EXPORT
    integer                  ,intent(in)  :: l
    real(kind=rp),dimension(l),intent(in)  :: d,b
    real(kind=rp),dimension(l),intent(in)  :: dd
    real(kind=rp),dimension(l),intent(out) :: xc
    !     LOCAL
    integer                  :: k
    real(kind=rp),dimension(l):: gam
    real(kind=rp)             :: bet

    bet   = 1._8/d(1)
    xc(1) = b(1)*bet
    do k=2,l
       gam(k)= dd(k-1)*bet
       bet     = 1._8/(d(k)-dd(k-1)*gam(k))
       xc(k) = (b(k)-dd(k-1)*xc(k-1))*bet
    enddo
    do k=l-1,1,-1
       xc(k) = xc(k)-gam(k+1)*xc(k+1)
    enddo
    
  end subroutine tridiag

  !----------------------------------------
  subroutine compute_residual(lev,res)
    integer(kind=ip), intent(in):: lev
    real(kind=rp), intent(out):: res

    real(kind=rp),dimension(:,:,:), pointer:: p
    real(kind=rp),dimension(:,:,:), pointer:: b
    real(kind=rp),dimension(:,:,:), pointer:: r
    real(kind=rp),dimension(:,:,:,:), pointer:: cA

    integer(kind=ip) :: nx, ny, nz, nh

    p  => grid(lev)%p
    b  => grid(lev)%b
    r  => grid(lev)%r
    cA => grid(lev)%cA

    nx = grid(lev)%nx
    ny = grid(lev)%ny
    nz = grid(lev)%nz
    nh = grid(lev)%nh

    if (grid(lev)%nz == 1) then
       call compute_residual_2D(res,p,b,r,cA,nx,ny)
    else
       call tic(lev,'compute_residual_3D')

       call compute_residual_3D(res,p,b,r,cA,nx,ny,nz)

       call toc(lev,'compute_residual_3D')
    end if

    if (lev >-1) then
       call global_max(res)
    else
       res = -999._8
    endif

  end subroutine compute_residual

  !----------------------------------------
  subroutine compute_residual_2D(res,p,b,r,cA,nx,ny)
    real(kind=rp)                            , intent(out)  :: res
    real(kind=rp),dimension(:,:,:)  , pointer, intent(inout):: p
    real(kind=rp),dimension(:,:,:)  , pointer, intent(in)   :: b
    real(kind=rp),dimension(:,:,:)  , pointer, intent(in)   :: r
    real(kind=rp),dimension(:,:,:,:), pointer, intent(in)   :: cA
    integer(kind=ip)                        , intent(in)   :: nx, ny

    integer(kind=ip) :: i,j,k

    res = 0._8

    k=1

    do i = 1,nx
       do j = 1,ny

          r(k,j,i) = b(k,j,i)                                           &
               - cA(1,k,j,i)*p(k,j,i)                                   &
               - cA(2,k,j,i)*p(k  ,j-1,i) - cA(2,k  ,j+1,i)*p(k  ,j+1,i)&
               - cA(3,k,j,i)*p(k  ,j,i-1) - cA(3,k  ,j,i+1)*p(k  ,j,i+1)

          res = max(res,abs(r(k,j,i)))

       enddo
    enddo

  end subroutine compute_residual_2D
  !----------------------------------------
  subroutine compute_residual_3D(res,p,b,r,cA,nx,ny,nz)

    real(kind=rp)                            , intent(out)  :: res
    real(kind=rp),dimension(:,:,:)  , pointer, intent(inout):: p
    real(kind=rp),dimension(:,:,:)  , pointer, intent(in)   :: b
    real(kind=rp),dimension(:,:,:)  , pointer, intent(in)   :: r
    real(kind=rp),dimension(:,:,:,:), pointer, intent(in)   :: cA
    integer(kind=ip)                        , intent(in)   :: nx, ny, nz

    ! Coefficients are stored in order of diagonals
    ! cA(1,:,:,:)      -> p(k,j,i)
    ! cA(2,:,:,:)      -> p(k-1,j,i)
    ! cA(3,:,:,:)      -> p(k+1,j-1,i)
    ! cA(4,:,:,:)      -> p(k,j-1,i)
    ! cA(5,:,:,:)      -> p(k-1,j-1,i)
    ! cA(6,:,:,:)      -> p(k+1,j,i-1)
    ! cA(7,:,:,:)      -> p(k,j,i-1)
    ! cA(8,:,:,:)      -> p(k-1,j,i-1)
    !
    integer(kind=ip)           :: i,j,k

    res = 0._8

    do i = 1,nx
       do j = 1,ny

          k=1!lower level
          r(k,j,i) = b(k,j,i)                                           &
               - cA(1,k,j,i)*p(k,j,i)                                   &
               - cA(2,k+1,j,i)*p(k+1,j,i)                               &
               - cA(3,k,j,i)*p(k+1,j-1,i)                               &
               - cA(4,k,j,i)*p(k  ,j-1,i) - cA(4,k  ,j+1,i)*p(k  ,j+1,i)&
               - cA(5,k+1,j+1,i)*p(k+1,j+1,i)                           &
               - cA(6,k,j,i)*p(k+1,j,i-1)                               &
               - cA(7,k,j,i)*p(k  ,j,i-1) - cA(7,k  ,j,i+1)*p(k  ,j,i+1)&
               - cA(8,k+1,j,i+1)*p(k+1,j,i+1)

          res = max(res,abs(r(k,j,i)))

          do k = 2,nz-1!interior levels
             r(k,j,i) = b(k,j,i)                                           &
                  - cA(1,k,j,i)*p(k,j,i)                                   &
                  - cA(2,k,j,i)*p(k-1,j,i)   - cA(2,k+1,j,i)*p(k+1,j,i)    &
                  - cA(3,k,j,i)*p(k+1,j-1,i) - cA(3,k-1,j+1,i)*p(k-1,j+1,i)&
                  - cA(4,k,j,i)*p(k  ,j-1,i) - cA(4,k  ,j+1,i)*p(k  ,j+1,i)&
                  - cA(5,k,j,i)*p(k-1,j-1,i) - cA(5,k+1,j+1,i)*p(k+1,j+1,i)&
                  - cA(6,k,j,i)*p(k+1,j,i-1) - cA(6,k-1,j,i+1)*p(k-1,j,i+1)&
                  - cA(7,k,j,i)*p(k  ,j,i-1) - cA(7,k  ,j,i+1)*p(k  ,j,i+1)&
                  - cA(8,k,j,i)*p(k-1,j,i-1) - cA(8,k+1,j,i+1)*p(k+1,j,i+1)

             res = max(res,abs(r(k,j,i)))
          enddo

          k=nz!upper level
          r(k,j,i) = b(k,j,i)                                           &
               - cA(1,k,j,i)*p(k,j,i)                                   &
               - cA(2,k,j,i)*p(k-1,j,i)                                 &
               - cA(3,k-1,j+1,i)*p(k-1,j+1,i)                           &
               - cA(4,k,j,i)*p(k  ,j-1,i) - cA(4,k  ,j+1,i)*p(k  ,j+1,i)&
               - cA(5,k,j,i)*p(k-1,j-1,i)                               &
               - cA(6,k-1,j,i+1)*p(k-1,j,i+1)                           &
               - cA(7,k,j,i)*p(k  ,j,i-1) - cA(7,k  ,j,i+1)*p(k  ,j,i+1)&
               - cA(8,k,j,i)*p(k-1,j,i-1)
          
          res = max(res,abs(r(k,j,i)))
   
       enddo
    enddo

  end subroutine compute_residual_3D

end module mg_relax