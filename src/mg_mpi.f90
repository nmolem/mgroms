module mg_mpi

  use mpi

  implicit none

  integer(kind=4), parameter:: is=4, rl=8

  integer(kind=is) :: rank
  integer(kind=is) :: nprocs

  ! local dimensions which will come from the outside (ROMS)
  integer(kind=is) :: nxo, nyo, nzo

  ! http://www.open-mpi.org/doc/v1.8/man3/MPI_Recv_init.3.php

contains

  !----------------------------------------
  subroutine init_mpi(nxg, nyg, nzg, npxg, npyg)

    integer(kind=is), intent(in) :: nxg, nyg, nzg
    integer(kind=is), intent(in) :: npxg, npyg

    integer(kind=is) :: ierr

    call mpi_init(ierr)

    call mpi_comm_rank(mpi_comm_world, rank, ierr)

    call mpi_comm_size(mpi_comm_world, nprocs, ierr)

    if (nprocs /= (npxg*npyg)) then
       write(*,*) "Error: in number of processes !"
       stop 
    endif

    ! WARNING, non divisibility issues !
    nxo = nxg / npxg 
    nyo = nyg / npyg
    nzo = nzg

  end subroutine init_mpi

  !----------------------------------------
  SUBROUTINE mg_mpi_finalize

    integer(kind=is) :: ierr

    ! Desactivation de MPI
    CALL MPI_FINALIZE(ierr)

  END SUBROUTINE mg_mpi_finalize


end module mg_mpi